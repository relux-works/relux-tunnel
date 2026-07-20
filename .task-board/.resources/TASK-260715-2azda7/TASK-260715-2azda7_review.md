# TASK-260715-2azda7 — Review (reviewer, claude)

Date: 2026-07-20
Verdict: **ACCEPTED → done**
Schema SHA-256 (independently recomputed): `3dd1bc9d8d0c1f9127cad05913137754da61d2657e8d0b8c0b30108e331e8000`

## What was reviewed

Full read of `Protocol/Relay/relay-v1.schema.json` (396 lines),
`scripts/relay-protocol-tool.py` (2014 lines, all of it), both generated
outputs' structure via the emitters plus the Swift file header/identity
sections, both handwritten parity test suites, all 12 negative fixtures,
`scripts/tests/test-relay-protocol-go.sh`, `relay/README.md`, and the
Makefile/README diffs. All verification commands re-run independently.

## AC verification

1. **Single authority, no duplicated handwritten values — PASS.** Schema covers
   magic/version, exact 12/16-byte hello layouts, envelope prefix+header with
   `type-through-payload` length coverage, all 6 message types with
   direction/associationID/payload metadata, hello flag + feature + envelope
   flag bits with computed reserved masks, reserved message-type range
   0x40–0x4F, 3 address types, HEV record layout, 5 hello statuses, 10 UDP
   error codes, and 8 limits. Every limit row cross-checked verbatim against
   the frozen TASK-260715-18owh7 §4.1–4.3 tables (incl. asymmetric aggregate
   ceilings 4 MiB client / 16 MiB relay and idleTimeout 60s/120s) and the
   §6 schema-handoff note on the board; nothing invented. The tool's
   `FROZEN_V1` table is a compatibility guard only, explicitly documented as
   not a constants source; no handwritten runtime code restates wire values
   (test spot-checks are drift assertions, which is their job).
2. **Deterministic pinned generation — PASS.** `make relay-protocol-generate`
   pins `LC_ALL=C LANG=C TZ=UTC PYTHONHASHSEED=0`; emitters have no
   timestamps/abs-paths/hash-order iteration; Go output is gofmt-canonical.
   The check gate regenerates twice into fresh `.temp` roots and
   byte-compares both runs and both checked-in files — observed passing.
3. **Validation rejections — PASS.** Strict unknown-key rejection, duplicate
   name/value/bit detection, width overflow, floor/default/ceiling ordering,
   fixedWireConstant equality, direction/associationID enums, reserved-range
   overlap (vs allocated types and each other), contiguity of status/error
   vocabularies (append-only growth), canonical-JSON round-trip, plus the
   frozen-v1 guard for hello layout, message table, address types, flag/bit
   reassignment, maxFrame range, and maxUDPPayload edits. All 12 negative
   fixtures verified to fail with the expected error substring.
4. **Runtime artifacts are pure constants — PASS.** Swift file: zero imports,
   `Sendable` value types, lives in `ReluxTunnelCore` only
   (`make check-core-boundaries` PASS). Go file: zero imports, constants and
   tables only. No generator/network/reflection/schema parsing at runtime.
5. **CI drift gate — PASS.** `make relay-protocol-check` chains: schema
   validation → 12 negative fixtures → double regen → byte-compare vs
   checked-in → embedded `Schema-SHA256` verification → stale/manual-edit
   self-test (truncated outputs + mutated digest header must be detected;
   exercised on every run) → gofmt/vet/`go test` (8 tests) → `swift build` →
   `swift test --filter RelayProtocol` (7 tests). Implementer additionally
   live-demoed a hand edit (1472→1473 in generated Go) failing the gate
   exit 1; demo diffs present in `.temp/relay-protocol-demo/`.

## Independent runs (2026-07-20)

- `make relay-protocol-check` — PASS end to end (twice).
- `swift test` full suite — 117/117 in 13 suites PASS.
- `make check-core-boundaries` — PASS.
- `swift format lint --recursive Sources Tests Package.swift` — 0 warnings.
- `python3 scripts/relay-protocol-tool.py digest` matches the embedded header
  digest in both generated files.
- Post-gate `git status` — no tracked files mutated by the gate (scratch
  confined to `.temp/`).

## Cross-language parity mechanism (assessed sound)

The generator embeds identical canonical parity lines + SHA-256 in both
outputs; each language's handwritten test re-derives the lines from typed
metadata. A hand edit to any constant breaks the in-language test before the
file-level byte-compare even runs. This gives two independent drift layers
without shared runtime code or FFI, consistent with the 111tde review rule
that generated diffs are reviewed mechanically.

## Accepted deviations (documented, non-blocking)

1. `relay/go.mod` deliberately not created — module scaffold is owned by
   TASK-260715-27uz4n; the Go smoke uses a throwaway `.temp/` module with
   `GOTOOLCHAIN=local`, network-free. Path `relay/internal/protocol` already
   matches the binding ADR, so no rework when the module lands.
2. Workstation Go is 1.25.5 (pinned 1.26.5 absent). Residual risk: if the
   pinned toolchain's gofmt ever formats this output shape differently, the
   byte-compare will flag it at 27uz4n/CI time — the gate fails loudly, it
   cannot drift silently. Acceptable.
3. Reviewer role is read-only, so the stale-detection failure path was
   verified via the gate's built-in self-test (runs every check) plus code
   inspection of `compare_files`/`extract_header_digest`, not by hand-editing
   checked-in files; the implementer's recorded live demo covers the
   end-to-end exit-1 path.

## Definition of Done

All checklist items satisfied: bindings generated+compiled from one schema,
validation + drift fixtures, regeneration commands + representative diffs
attached (results resource + `.temp/relay-protocol-demo/`), tests written and
green, lint clean, builds verified, outcome artifact on the board, logbook
entry recorded (1637), AC matched, architecture fit confirmed.
