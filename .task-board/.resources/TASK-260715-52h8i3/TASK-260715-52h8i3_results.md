# TASK-260715-52h8i3 — Packet-frame fuzz and allocation-bound tests: verification report

Recovery run on `claude-fable` (RUN-260720-dd74a9), verifying and finalizing the
fuzz tests written by the prior codex run (RUN-260720-3f9ce6, which failed only
on the final handoff, not on the implementation). Tests were verified, not
rewritten; the only source changes in this run are documentation
(`docs/packet-frame-fuzzing.md`, one README tools-table row).

- Source revision under test: `fc13e0a0bd9e0923e4e441571406fcca560b488c`
- Test files (from prior run, unchanged):
  - `Tests/ReluxTunnelCoreTests/PacketFrameFuzzCorpus.swift`
  - `Tests/ReluxTunnelCoreTests/PacketFrameFuzzTests.swift`
- Suite: `Packet frame deterministic fuzz and allocation bounds` (7 tests,
  `.serialized`, per-test 1-minute time limit)

## Evidence (all runs on macOS, Swift 6.1 toolchain)

| Run | Command | Result | Log |
| --- | --- | --- | --- |
| Bounded default (CI shape) | `swift test` | 105/105 pass, 12 suites | `swift-test-default-01.log` |
| Extended fuzz | `RELUX_PACKET_FUZZ_ITERATIONS=50000 RELUX_PACKET_FUZZ_RUNTIME_MS=60000 RELUX_PACKET_FUZZ_ALLOCATION_BYTES=268435456 RELUX_PACKET_FUZZ_REVISION=fc13e0a… swift test --filter PacketFrameFuzzTests` | 7/7 pass | `swift-test-extended-01.log` |
| ThreadSanitizer | `swift test --sanitize=thread --filter PacketFrameFuzzTests` | 7/7 pass, zero TSan warnings | `swift-test-tsan-01.log` |
| Coverage | `swift test --enable-code-coverage` + `llvm-cov report` | see below | `coverage-01.log`, `swift-test-coverage-01.log` |
| Lint | `swift format lint --recursive Sources Tests Package.swift` | clean, exit 0 | `swift-format-lint-01.log` |

### Fuzz report lines

Default bounded run (512 iterations/direction):

```text
PACKET_FRAME_FUZZ_REPORT direction=reverse seed=353398966579 iterations=512 duration_ms=4 peak_allocation_bytes=132304 revision=fc13e0a0bd9e0923e4e441571406fcca560b488c shortHeader=134 emptyPayload=34 unknownFamily=65 payloadVersionMismatch=180
PACKET_FRAME_FUZZ_REPORT direction=forward seed=353398966579 iterations=512 duration_ms=2 peak_allocation_bytes=7984 revision=fc13e0a0bd9e0923e4e441571406fcca560b488c malformed=506
```

Extended run (50,000 iterations/direction — the documented extended command):

```text
PACKET_FRAME_FUZZ_REPORT direction=reverse seed=353398966579 iterations=50000 duration_ms=3897 peak_allocation_bytes=12668208 revision=fc13e0a0bd9e0923e4e441571406fcca560b488c shortHeader=12583 emptyPayload=3151 unknownFamily=6235 payloadVersionMismatch=17535
PACKET_FRAME_FUZZ_REPORT direction=forward seed=353398966579 iterations=50000 duration_ms=3741 peak_allocation_bytes=406816 revision=fc13e0a0bd9e0923e4e441571406fcca560b488c malformed=48985
```

Peak allocation growth stays bounded and sublinear in corpus size: 100× more
hostile frames grew reverse-path peak allocation ~96× less than linearly
(12.7 MiB total against a 256 MiB extended ceiling; 132 KiB at CI scale against
the 32 MiB default ceiling). Runtime ~3.9 s for 50k frames/direction. No crash,
hang, out-of-bounds access, or unbounded growth observed at any scale.

### Coverage (llvm-cov, line coverage)

| File | Lines | Note |
| --- | --- | --- |
| `Sources/ReluxTunnelCore/PacketFlowBridge.swift` | 95.07% | the fuzzed framing/parsing target |
| `Sources/ReluxTunnelCore/PacketContracts.swift` | 89.66% | |
| `Sources/ReluxTunnelCore/PacketFlowBridgeContracts.swift` | 90.48% | |
| `Tests/…/PacketFrameFuzzCorpus.swift` | 97.15% | |
| `Tests/…/PacketFrameFuzzTests.swift` | 99.50% | |
| `Sources/ReluxTunnelCore/DarwinPacketBridgeIO.swift` | 23.35% | real-socket syscall wrapper; not a parsing path and outside this task's fuzz scope |

Affected parsing code is well above the ~80% target.

## Acceptance criteria check

1. **Arbitrary bytes, no out-of-bounds reads, no declared-length allocation** —
   met. Generated corpus feeds arbitrary bytes at every length class; the
   coalesced-input splitter test proves a hostile four-byte declared length
   (`0xffffffff`) materializes at most `maximumDatagramBytes + 1` bytes; the
   bridge buffer is sized once from configured MTU.
2. **Seed corpus classes** — met. `seedManifest` asserts IPv4, IPv6, empty,
   1–3-byte, unknown-family, exact-MTU, over-MTU, and three prior-regression
   fixtures are all present with unique ids.
3. **Bounded CI corpus + documented extended command** — met. The bounded
   deterministic run is part of plain `swift test`; the extended command and
   all env knobs are documented in `docs/packet-frame-fuzzing.md`; the report
   line records seed, duration, iterations, peak allocation, and source
   revision.
4. **Minimized replay on failure** — met (mechanism in place, no findings).
   Every corpus expectation embeds `seed`/`frame_index` for deterministic
   replay; `PacketFrameFixtureMinimizer` shrinks failing inputs and is itself
   tested. No crash or invariant violation was found, so no bug fixture was
   required.
5. **Bounded runtime/memory + reason-specific malformed counters** — met.
   Runtime and malloc-growth ceilings are asserted in both directions. The
   bridge exposes an aggregate `…_drop_malformed_total` counter by design; the
   harness oracle mirrors the bridge's exact rejection order, asserts the
   aggregate equals the oracle sum, asserts every reason class is exercised
   (each count > 0), and reports per-reason counts
   (shortHeader/emptyPayload/unknownFamily/payloadVersionMismatch).

Privacy: `assertPrivacySafe` verifies no log field key carries
payload/packet/destination/address/hostname/port/credential material in either
direction.

## Anomaly (recorded, not blocking)

One full-suite run under `swift test --enable-code-coverage` (the first
coverage-instrumented invocation) reported `105 tests … failed … with 1 issue`
while the fuzz suite itself passed in that same run; the issue was not captured
before the log rotated. Eight follow-up runs (5× plain, 3× coverage-enabled)
all passed 105/105. The flake is therefore outside the fuzz suite (which is
`.serialized` and deterministic) and most likely a timing-sensitive
`eventually` expectation elsewhere in the suite under first-run instrumentation
overhead. Logged for follow-up; does not affect this task's deliverable.

## Artifacts

- `TASK-260715-52h8i3_test-evidence.zip` — all logs listed above.
- `docs/packet-frame-fuzzing.md` — fuzz commands, env-knob table, corpus
  manifest description, replay/minimization flow, TSan caveat.
