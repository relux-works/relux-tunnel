# TASK-260715-2z9b4a logbook

Date: 2026-07-20

## Findings and disposition

- The accepted schema, both generated bindings, ADR-021, 89-vector corpus, and
  paired Swift/Go state machines agree on v1 layout, values, limits, and failure
  scopes. Regeneration produced no tracked protocol/vector diff.
- The earlier vector-report anomaly is resolved: `.spec/decisions.md` now
  contains accepted ADR-021. No duplicate clarification task is needed.
- The current `.github/workflows/ci.yml` does not invoke
  `make relay-protocol-check`. Existing atomic owners are
  `TASK-260715-1m3edc` (shared-core/protocol CI) and `TASK-260715-36gq4m`
  (four-target relay release matrix); the canonical contract is linked to both.
- The local Go gate uses Go 1.25.5 through a temporary standard-library-only
  module. It is accepted conformance evidence but not Go 1.26.5 release proof.
  `TASK-260715-27uz4n` already owns the pinned relay module/toolchain.
- All build/bootstrap/UDP/capability consumer work already exists as atomic
  tasks with descriptions, acceptance criteria, and dependencies. Creating
  duplicates would split ownership, so the contract is linked to those tasks
  instead.

## Verification summary

- Deterministic schema generation: pass; schema SHA-256 `3dd1…8000`; no diff.
- Deterministic vector generation/check: pass; 89 vectors; SHA-256
  `e21e…e76`; no diff.
- Cross-language conformance: pass; 57 Swift protocol tests and Go vet/tests.
- Hostile diagnostics: pass under Go `checkptr=2` and Swift AddressSanitizer.
- Go fuzz: pass for 30 seconds and 12,766,542 executions.
- Full `make relay-protocol-check`: pass, including 12 negative fixtures,
  double generation, drift/digest checks, stale/manual-edit self-test, and
  Swift build.

## Diagram tooling

No `plantuml` executable or local JAR was installed in PATH. A fixed PlantUML
1.2026.6 JAR was therefore downloaded into a task-local temporary directory,
used to validate the task-scoped activity source, and used to render the
checked-in SVG. The JAR and PNG preview were not added to the repository.
