# Packet-frame fuzz and allocation-bound testing

This document records the deterministic fuzz surface introduced by
`TASK-260715-52h8i3` for the `PacketFlowBridge` framing paths
(`TASK-260715-3o0co4`) and the HEV-facing datagram boundary. It proves the
`TASK-260715-p89bdj` bounds contract over hostile input: malformed frames are
rejected with bounded per-frame and aggregate allocation, monotonic drop
counters, no crash/hang, and privacy-safe logs. A bounded run is **not** an
exhaustive security proof.

## Test surface

Everything lives in `Tests/ReluxTunnelCoreTests/`:

| File | Contents |
| --- | --- |
| `PacketFrameFuzzCorpus.swift` | Seed corpus manifest, disposition oracle, seeded `SplitMix64` frame generator, coalesced-input splitter, fixture minimizer, malloc peak sampler |
| `PacketFrameFuzzTests.swift` | Suite `Packet frame deterministic fuzz and allocation bounds` — replays the corpus through the real bridge over `FakePacketFlow`/`FakeDatagramSocketIO` fixtures |

### Seed corpus manifest

The replayable seed corpus (`PacketFrameFuzzCorpus.seeds`) covers every class
required by the acceptance criteria; the `seedManifest` test fails if a class
disappears:

- IPv4 and IPv6 minimum frames
- empty datagram; 1-, 2-, and 3-byte undersized datagrams
- unknown address family (`Int32.max` family word)
- exact-MTU and over-MTU frames
- prior regressions: family word with no payload, and family/payload
  version-mismatch pairs in both directions

Generated frames extend the seeds: a seeded `SplitMix64` stream drives frame
lengths through the `0, 1, 2, 3, 4, exact-max, over-max, random` schedule with
random payloads and family words, so every replay of the same seed produces
byte-identical corpora.

### Oracle and counters

`PacketFrameFuzzCorpus.classify` mirrors the bridge's rejection order exactly
(oversized → fatal; `<4` bytes → short header; `==4` → empty payload; unknown
family; payload version mismatch). The reverse-path test asserts the bridge's
aggregate `packet_bridge_reverse_drop_malformed_total` equals the oracle's sum,
asserts every reason class is exercised (each per-reason count `> 0`), and
prints the per-reason breakdown. The bridge intentionally exposes only the
aggregate counter; reason-specific counting is asserted at the harness level.

## Commands

### Bounded CI run (default)

The suite is part of the normal package tests — no extra wiring:

```sh
swift test                     # or: make core-test / make validate-core
```

Defaults: seed `0x5248384933`, 512 iterations per direction, 5 s runtime
ceiling, 32 MiB allocation-growth ceiling. The suite is `.serialized` with a
1-minute `.timeLimit` backstop per fuzz test.

### Extended run

```sh
RELUX_PACKET_FUZZ_SEED=0x5248384933 \
RELUX_PACKET_FUZZ_ITERATIONS=50000 \
RELUX_PACKET_FUZZ_RUNTIME_MS=60000 \
RELUX_PACKET_FUZZ_ALLOCATION_BYTES=268435456 \
RELUX_PACKET_FUZZ_REVISION="$(git rev-parse HEAD)" \
swift test --filter PacketFrameFuzzTests
```

| Variable | Meaning | Default | Ceiling |
| --- | --- | --- | --- |
| `RELUX_PACKET_FUZZ_SEED` | Deterministic generator seed (decimal or `0x…`) | `0x5248384933` | — |
| `RELUX_PACKET_FUZZ_ITERATIONS` | Generated frames per direction | `512` | `50000` |
| `RELUX_PACKET_FUZZ_RUNTIME_MS` | Asserted wall-clock ceiling per direction | `5000` | `60000` |
| `RELUX_PACKET_FUZZ_ALLOCATION_BYTES` | Asserted malloc-growth ceiling | `33554432` | `536870912` |
| `RELUX_PACKET_FUZZ_REVISION` | Source revision stamped into the report | `unspecified` | — |

Each direction prints one machine-readable evidence line:

```text
PACKET_FRAME_FUZZ_REPORT direction=<forward|reverse> seed=<n> iterations=<n>
  duration_ms=<n> peak_allocation_bytes=<n> revision=<sha>
  [shortHeader=<n> emptyPayload=<n> unknownFamily=<n> payloadVersionMismatch=<n> | malformed=<n>]
```

### ThreadSanitizer run

```sh
swift test --sanitize=thread --filter PacketFrameFuzzTests
```

Note: TSan interposes malloc, so `peak_allocation_bytes` reads `0` under this
run; the allocation assertion is meaningful only in the non-sanitized runs.

## Replay and minimization

Every corpus-driven expectation embeds `seed=… frame_index=…` (or
`packet_index=…`) in its failure message, so a red run identifies the exact
deterministic frame to replay. `PacketFrameFixtureMinimizer.minimize` shrinks a
failing input to a minimal fixture while the supplied predicate keeps failing;
`packetFrameHex` renders it as a replayable hex fixture. Any crash or invariant
violation must land as a minimized fixture plus a concrete bug before the fuzz
task can pass (stop-the-line).

## Allocation-bounds design

Untrusted declared lengths never size an allocation: the coalesced-input
splitter materializes at most `maximumDatagramBytes + 1` bytes per frame
regardless of the four-byte declared length, and the bridge's receive buffer is
sized once from the configured MTU. The fuzz tests sample
`malloc_zone_statistics` around the replay loop and assert peak growth stays
under the configured ceiling in both directions.
