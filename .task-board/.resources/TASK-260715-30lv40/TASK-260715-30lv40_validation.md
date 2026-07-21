# TASK-260715-30lv40 — rework-03 and commit-hygiene validation evidence

## Contract audit

- State rows: 11.
- External legal transitions: 32 (`T01` through `T32`).
- Internal registration phases: seven, adding finite `reconnectValidator`.
- `M2CapabilityReasonV1` rows: 59; retry classes: five.
- Required platform, asset, bootstrap, checksum, launch, version, feature, limit,
  framing, health, process, lane, safe-DNS, stop, stale-generation, activation,
  and reprobe-exhaustion tokens: present.

Rework-03 closes the review-03 predicate contradiction as executable
requirements:

1. `DegradedRegistrationProof` is state-dependent: plain degraded has no M2
   registration, Waiting has exactly one current `reprobeWaiting` registration,
   and Running has exactly one current `reprobeAttempt` registration.
2. All three branches retain current `BaseReady`, null active relay, closed UDP,
   and invalidated retired associations. Waiting/Running therefore truthfully
   publish `(1,1,0)` while prospective work is registered; any missing,
   duplicate, wrong-phase, or wrong-tuple registration projects no usable bits.
3. T14/T15/T19/T22 establish the exact target lifecycle and registration before
   re-evaluating `Degraded(g)`. The state table, lifecycle note, snapshot
   projection, reviewer packet, and race-test handoff use the same rule.

The rework-02 requirements remain intact:

- `ValidatedRelayCandidate` is current internal proof with active relay null,
   UDP closed, and no admitted association. T04 cannot expose active identity.
   T07 guards on current base plus candidate, then atomically binds, promotes,
   opens, proves `Full`, and publishes.
- M3 has an exact local validation-start event after current `BaseReady`, a
   captured six-field tuple, finite `reconnectValidator` phase, exhaustive legal
   callbacks, and clear/promote-before-publication retirement. Candidate success
   feeds T26; finite failure feeds T27; only T26 can bind/open/publish full.

Rework-01 invariants remain intact: clear-before-cleanup retirement, T15 bounded
local-policy re-arm, finite `activation_ready`, and registered reprobe
Waiting/Running phases.

## Post-acceptance commit-hygiene validation

- Removed only the Markdown hard-break trailing spaces from metadata lines 3,
  5, 6, and 7 of the binding contract and all 16 downstream copies.
- The corrected binding contract and every downstream copy are byte-identical
  with SHA-256
  `5b57540c86a0b48595863174e416229babee72cdb2705dd4bbb81bbefdc9ab69`.
- A direct trailing-blank scan over all 17 files returns no matches.
- `git diff --check` and `git diff HEAD --check` pass. An isolated complete Git
  index containing staged, unstaged, and untracked artifacts also passes
  `git diff --cached --check`; the user's real staging area was not changed.
- No state, transition, reason, readiness, generation, snapshot, retry,
  privacy, diagram, production gate, or M1/M2/M3/UI ownership rule changed.

## Diagram validation

PlantUML `1.2026.6` under OpenJDK passed `-checkonly` and deterministic PNG
render for both task-scoped sources. A second render was byte-identical.

- Lifecycle PNG: 3394 x 968 RGB. Visual inspection at original resolution
  confirmed readable startup candidate promotion, registered reprobe
  Waiting/Running, M3 Awaiting Base/Validating Relay, T26/T27, stop, and failure
  paths with no clipping.
- Ownership PNG: 2329 x 781. Visual inspection confirmed single-purpose
  M1/M2/M3/system/app boundaries, one validation-start event per transport
  attempt, candidate ownership, reconnect cadence ownership, and privacy notes.

## Executable and repository gates

```text
make core-test
make relay-protocol-check
make relay-shell-test
task-board validate
git diff --check
git diff HEAD --check
GIT_INDEX_FILE=<task-scoped-isolated-index> git diff --cached --check
```

Results:

- Core Swift: 306 tests in 27 suites passed.
- RelayProtocol Swift: 57 tests in seven suites passed; deterministic 89-vector
  reproduction, Go protocol tests, schema regeneration/parity, negative
  fixtures, and Swift build passed.
- Relay shell: all Go relay packages passed; 11 release-script tests passed.
- Board validation plus working-tree, HEAD-inclusive, and isolated
  complete-index diff whitespace checks passed.
- Privacy scan found no absolute workstation path, private-key block,
  secret-value assignment, URL, or literal IP address in the contract,
  diagrams, reviewer packet, or rework outcome. Remote strings and sensitive
  traffic values remain structurally forbidden.

## Resource and copy verification

- The corrected binding contract, reviewer packet, and validation evidence were
  attached through `task-board resource update`.
- All 16 downstream task-scoped precondition copies were updated through the
  board resource API and compared byte-for-byte with the binding contract:
  pass.
- No dependency link was added or changed. The previously logged broad
  `plan(..., mode=related)` anomaly remains outside this bounded rework;
  `task-board validate` is clean.
- The automatic zero-byte raw solution-architect spawn-log resource was removed
  before handoff; no raw spawn log remains among task outcomes.

## SHA-256

| Artifact | SHA-256 |
| --- | --- |
| `TASK-260715-30lv40_capability-contract.md` | `5b57540c86a0b48595863174e416229babee72cdb2705dd4bbb81bbefdc9ab69` |
| `TASK-260715-30lv40_capability-state-plan.puml` | `a9e9c03940ba4a08337219f634d7dd2d7164cde7d1b847d84b518baf20578df5` |
| `TASK-260715-30lv40_ownership-boundaries.puml` | `0560e9813e27d1e199170a51ff15f5726edc53dbb5c665234426aa802157f3b8` |
| `TASK-260715-30lv40_reviewer-packet.md` | `a14f5e28c966112998aa8a2e0bbe6663536e2548af19843bbc9e3ce904147b75` |
| `TASK-260715-30lv40_capability-state-plan.png` | `1aa14dd76b68b6ef38caecbac3d7cf15ae2b572a3b4778d18ea07e17930db275` |
| `TASK-260715-30lv40_ownership-boundaries.png` | `928d103099635e71534adf5b70b2b8187d2bd78006b4dd08c4e73ce61ca03c35` |

Production full/degraded authorization remains gated by accepted M0 composition
and production-authorized DNS policy. No SSH engine, MTU, lane/window, timing,
retry, overlap, or DNS numeric value was selected by this rework.
