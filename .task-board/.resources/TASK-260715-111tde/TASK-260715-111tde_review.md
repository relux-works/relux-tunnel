# TASK-260715-111tde — Review verdict: ACCEPTED

Date: 2026-07-20
Reviewer: [reviewer] reviewer (claude), run RUN-260720-19e851
Deliverable reviewed: `TASK-260715-111tde_relay-binding-decision.md` plus ownership/session
diagrams, renders, validation log, task logbook, and 16 downstream precondition copies.

## Verdict

Accepted → `done`. The binding ADR satisfies all five acceptance criteria, honors the
orchestrator override, stays within the task's read-only constraint, and is faithful to
every accepted upstream contract it cites. Two minor, non-blocking blemishes are recorded
below for the orchestrator.

## AC verification

1. **Decision record and ownership (AC1) — PASS.** §1 cites accepted ADR-005/006
   (`.spec/decisions.md` verified), accepted `TASK-260715-3r0993` (matches ADR-016/017),
   `TASK-260715-2nfz7w`, `TASK-260715-3bdplx`, `TASK-260720-100wu6` — all four confirmed
   `done` on the board. §2 names exact schema (`Protocol/Relay/relay-v1.schema.json`),
   both generated outputs, every handwritten adapter, module placement, per-task owners,
   and a validation command per artifact.
2. **Deterministic regeneration and drift gate (AC2) — PASS.** One command
   (`make relay-protocol-generate`, pinned `LC_ALL/LANG/TZ/PYTHONHASHSEED`), checked-in
   reviewable generated diffs with digest headers, and `make relay-protocol-check` with
   double-generation byte-compare, checked-in comparison, embedded-digest verification,
   and a deliberate stale/manual-edit fixture that must fail. No collision with existing
   Makefile targets; implementation is correctly delegated to `TASK-260715-2azda7`.
3. **Bounded stream abstractions (AC3) — PASS.** Swift side binds to the real accepted
   contract (verified against `Sources/ReluxTunnelCore/SSHContracts.swift:1480-1527`:
   `openExecChannel(request:policy:)`, `read(maximumBytes:)`, `writeSome`,
   `finishWriting`, `readStandardError`, `waitForExit`) with no blocking syscalls,
   no `readToEnd`, no unchecked peer-sized allocation, checked shifts, no
   alignment-dependent unsafe loads. Go side: `io.Reader`/`io.Writer` +
   `encoding/binary.BigEndian`, blocking confined to one reader/one writer goroutine,
   single stdout owner, bounded injected limits, `io.ReadAll`/cgo/`unsafe`/goroutine-
   per-datagram forbidden. Fits the Apple extension and rootless Linux/macOS constraints.
4. **Dependency/license/trust ceiling (AC4) — PASS.** §5 enumerates per-boundary allowed
   and forbidden surfaces (Apple runtime, Go relay runtime, generator, tests), requires a
   new task-scoped decision for any unsafe/FFI/dependency escalation, defines the public
   error surface (stable code/phase/scope/disposition, no peer text or raw OS errors),
   and the source→build→runtime→release trust chain. Matches the accepted 3bdplx ceiling
   (Go 1.26.5 stdlib-only, `CGO_ENABLED=0`) exactly.
5. **Downstream mapping (AC5) — PASS.** All 32 consumer task IDs spot-checked in §7 exist
   on the board; each maps to a concrete artifact or interface. The single unresolved
   decision (numeric limits and their exchange mechanism) is explicitly owned by the
   unblocked `TASK-260715-18owh7`; no values were invented. §8.5: no downstream task has
   an unresolved language, project-boundary, transport-engine, or FFI choice.

## Wire-contract fidelity

- Hello (12/16 bytes), envelope (`frameLength:u32|type:u8|flags:u8|associationID:u32`),
  message table (0x10/0x11/0x20/0x21/0x30/0x31 with directions), and the HEV payload
  layout match `.spec/relay-protocol.md` exactly; additions (status codes, error codes,
  feature bit 0, association-ID zero/nonzero rules) are compatible schema-owned
  elaborations the task was chartered to freeze.
- HEV `HDRLEN` arithmetic (10 IPv4 / 22 IPv6 / 7+N domain, domain ≤ 248 via one-byte
  `HDRLEN`) independently confirmed against the pinned upstream audit
  `.research/260720_pin-and-audit-hev-lwip-baseline.md:208-225`.
- Validation-before-socket-use matches `.spec/security-privacy.md:65-66`.
- Identity preflight (`--identity --protocol 1`) is a new, spec-compatible elaboration of
  bootstrap step 5 ("protocol-level self-hash where available"); it changes no v1 wire
  byte, and §8.2 records the rejected alternatives — within the override's allowance for
  new decisions.

## Override and process compliance

- Gate A0 (`TASK-260715-1828xy`) and `TASK-260715-32umrc` are not dependency edges;
  `blockedBy` is exactly the three accepted foundations. Board `validate` passes.
- Read-only constraint honored: working tree contains no product-code changes — only
  board resources, `diagrams/` sources (identical to board copies), `.research/` copy,
  and LOGBOOK entries from the analyst run.
- Both PlantUML sources render clean (PlantUML 1.2026.6, Smetana); renders inspected;
  the Graphviz `libltdl` anomaly is documented and non-blocking.
- Tests green: vacuously — the deliverable is a contract document; no Swift/Go source
  changed, so the suite state is that of the last accepted commit.

## Minor non-blocking findings (for the orchestrator)

1. `TASK-260715-111tde_foundation-blocked-analysis.md` is registered as "retained for
   override and routing provenance" but is a 0-byte file. The superseded analysis
   content survives verbatim in the task notes (STOP-LINE 2026-07-20) and LOGBOOK entry
   1510, so no decision provenance is lost, but the resource contradicts its own
   description. Recommend either deleting the resource or restoring a short pointer body.
2. The 248-byte domain cap is below the 253-byte DNS presentation maximum. This is
   inherited from the accepted upstream HEV framing (ADR-004), already documented in the
   HEV audit; recorded here so `TASK-260715-1q7u14` includes a boundary vector for it.
