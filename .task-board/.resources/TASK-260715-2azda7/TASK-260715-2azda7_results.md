# TASK-260715-2azda7 — Shared protocol schema and generated constants

Date: 2026-07-20
Status: implementation ready for review
Schema SHA-256: `3dd1bc9d8d0c1f9127cad05913137754da61d2657e8d0b8c0b30108e331e8000`

## What was built

One authoritative relay protocol v1 schema plus a deterministic build-time
generator that emits matching Swift and Go constant bindings, with a CI drift
gate. All numeric values come from the accepted TASK-260715-111tde binding ADR
and the accepted TASK-260715-18owh7 limit decision; nothing new was invented.

| Path | Kind |
| --- | --- |
| `Protocol/Relay/relay-v1.schema.json` | Handwritten canonical authority (canonical JSON: sorted keys, 2-space indent, ASCII, LF). Covers magic/version, hello layouts, envelope layout + length coverage, message type/direction/association/payload metadata, hello flag + feature + envelope flag bits with reserved masks, reserved message-type range 0x40-0x4F, address types, HEV record layout, 5 hello statuses, 10 bounded UDP error codes, and all 8 limits with `{class, width, unit, clientDefault, relayDefault, floor, clientHardCeiling, relayHardCeiling}` |
| `scripts/relay-protocol-tool.py` | Python-stdlib build-only validator + deterministic emitter (`validate`, `generate`, `check`, `digest`) |
| `Sources/ReluxTunnelCore/RelayProtocol/Generated/RelayProtocolV1+Generated.swift` | Generated Swift constants + typed metadata (checked in; core target only, no imports, Sendable, swift-format lint clean) |
| `relay/internal/protocol/generated_v1.go` | Generated Go constants + typed metadata (checked in; gofmt-canonical, stdlib-free) |
| `Protocol/Relay/Fixtures/invalid-schema/*.json` | 12 negative fixtures (patch format: base schema + mutation + expected error substring) |
| `Tests/ReluxTunnelCoreTests/RelayProtocol/RelayProtocolGeneratedTests.swift` | Handwritten Swift Testing drift guard (7 tests) |
| `relay/internal/protocol/parity_test.go` | Handwritten Go drift guard (8 tests) mirroring the Swift one |
| `scripts/tests/test-relay-protocol-go.sh` | Go compile/vet/test smoke in a throwaway `.temp/` module |
| `Makefile` | New `relay-protocol-generate` / `relay-protocol-check` targets |
| `relay/README.md`, `README.md` | Consumption + tools documentation |

## Regeneration commands (pinned)

```sh
make relay-protocol-generate   # env LC_ALL=C LANG=C TZ=UTC PYTHONHASHSEED=0; emits both files, gofmt-canonical Go
make relay-protocol-check      # full drift gate (below)
```

`relay-protocol-check` stages: schema validation (strict keys, widths,
duplicates, sorted arrays, canonical-form round-trip) -> 12 negative fixtures
must fail with the expected error -> generate twice into two fresh
`.temp/relay-protocol-check/` roots -> byte-compare the two runs -> byte-compare
against the checked-in outputs -> verify embedded `Schema-SHA256` headers ->
stale/manual-edit self-test (mutated outputs and a mutated digest header must be
detected) -> `gofmt -l` + `go vet` + `go test` on the Go package ->
`swift build` -> `swift test --filter RelayProtocol`.

## Cross-language parity mechanism

The generator renders every value into canonical language-neutral parity lines
and embeds the identical line array plus its SHA-256 in both outputs. The
handwritten Swift and Go tests re-derive the lines from the typed metadata
(enums, layout tables, bit assignments, limit specs) and compare against the
embedded fingerprint, so a hand edit to any constant fails tests in that
language even before `make relay-protocol-check` byte-compares files. Runtime
artifacts are pure constants: no generator, network, reflection, or schema
parsing in either process (AC4).

## Backward-compatibility guard

The tool carries a frozen-v1 invariant table (explicitly a compatibility guard,
not a constants source). For `wireVersion == 1` it rejects: magic/hello/envelope
layout changes, message-table changes, address-type changes, edits to the
existing statuses/error codes, flag/feature reassignment, reserved-range
changes, `maxFrame` acceptance-range changes, and any `maxUDPPayload`
fixedWireConstant edit — each reported as `incompatible v1 edit: ... (requires a
wireVersion bump)`. Appending error codes/statuses and retuning localCap
defaults within [floor, hardCeiling] stay legal (matches binding section 6).

## Representative generated diff

Compatible demo edit (append error code `QUOTA_EXHAUSTED = 11` to a schema copy)
produces exactly this mechanical Swift diff (Go diff is the mirror image;
full diffs in `.temp/relay-protocol-demo/{swift,go}.diff`):

```diff
-// Schema-SHA256: 3dd1bc9d8d0c1f9127cad05913137754da61d2657e8d0b8c0b30108e331e8000
+// Schema-SHA256: 7528e63a478a304c97b693ec0a8b724c0925c99751a8441062d89fd27ffed79f
 ...
+    case quotaExhausted = 0x000B
+    NamedValue(name: "QUOTA_EXHAUSTED", value: 11),
+    "udpErrorCode name=QUOTA_EXHAUSTED value=11",
-  paritySHA256 = "da2d6bb5..."
+  paritySHA256 = "aa0c3ea5..."
```

## Verification evidence (all run locally, 2026-07-20)

- `make relay-protocol-check` — PASS end to end: 12 fixtures rejected, double
  regeneration byte-identical, checked-in outputs match, digests OK,
  stale/manual-edit self-test OK, Go vet+test OK, `swift build` OK, 7 Swift
  RelayProtocol tests PASS.
- Live drift demo: hand-editing `MaxUDPPayload 1472 -> 1473` in the checked-in
  Go file makes `check` exit 1 with "checked-in generated outputs are stale or
  hand-edited"; restored and re-verified green.
- Full `swift test`: 117 tests in 13 suites, all PASS (no regression).
- `make check-core-boundaries` — PASS (generated Swift lives in
  `ReluxTunnelCore` only, imports nothing).
- `swift format lint --recursive Sources Tests Package.swift` — 0 warnings.
- Go smoke: `gofmt -l` clean, `go vet` + `go test` PASS (8 Go tests).

## Notes, deviations, and follow-ups

1. **Go module scaffold**: `relay/go.mod` is owned by TASK-260715-27uz4n and
   deliberately not created. The smoke compiles/tests `relay/internal/protocol`
   in a throwaway module under `.temp/relay-protocol-go-smoke/`; when the real
   module lands, the generated file and tests need no changes
   (see `relay/README.md`).
2. **Toolchain**: local Go is 1.25.5 (the 3bdplx pin 1.26.5 is not installed on
   this workstation); the smoke pins `GOTOOLCHAIN=local`, network-free.
   Generated-Go canonical form is defined by gofmt of the pinned toolchain —
   stable across gofmt versions for this output shape.
3. **Limit slot values** come verbatim from 18owh7 sections 4.1-4.3, including
   the reserved hello flag bit 1, feature bit 1 (`resourceLimitExchange`), and
   message types 0x40-0x4F (resource governance) as named reservations only.
4. `hevRecord.msglenLimit` cross-references the `maxUDPPayload` limit
   (fixedWireConstant), so MSGLEN's ceiling has exactly one authority.
5. Derived constants are computed, not restated: hello widths 12/16, HDRLEN
   10/22/7+len, max HEV record 1727, max legal frame body 1733 (validated
   against the maxFrame floor 2048), domain wire bytes 1..248.
