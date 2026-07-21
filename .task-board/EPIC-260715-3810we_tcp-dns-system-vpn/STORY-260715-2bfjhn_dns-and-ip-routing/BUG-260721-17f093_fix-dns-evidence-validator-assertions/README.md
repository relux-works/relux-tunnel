# Fix DNS evidence validator assertions

## Description
Correct the three bounded evidence-harness defects found by the second independent review while preserving productionAuthorization=false and the real SSH/memory blockers.

## Scope
In scope: timing boundary vectors that invoke the actual validator; authority-critical policy structure validation; exact reliability attempt/terminal assertions; regenerated self-tests, policy artifact, raw summaries, evidence bundle, copies, hashes, and a task-scoped result. Out of scope: production DNS runtime, choosing an SSH engine, accepting production numeric values, or removing the 1gjxer/1pn983 evidence gates.

## Acceptance Criteria
1. Every timing boundary vector exercises the real validator and independently mutates one relevant field; no self-comparison can pass tautologically. 2. Policy verification fails closed on productionAuthorization, authority class, blocker identities, physical-gate declaration, and required structural fields. 3. Reliability scenarios assert exact attempts, terminal owners, duplicate/late/cancellation counts, and cleanup state for every recorded case. 4. All published copies, raw hashes, archive members, privacy checks, board validation, and diff checks pass. 5. A fresh independent Codex reviewer accepts the bug fix; TASK-260721-3miqh4 remains honestly blocked on 1gjxer and 1pn983 rather than marked done.
