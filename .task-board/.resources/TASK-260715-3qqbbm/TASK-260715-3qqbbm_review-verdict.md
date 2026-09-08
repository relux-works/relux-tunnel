# TASK-260715-3qqbbm review verdict

## Verdict

Accepted Change Request `CR-TASK-260715-3qqbbm-1` revision 1, candidate tree
`bf9b73d562a89f87b50163b97e3e4bf29736e025` over base
`6a62fbab0aa085f6a279730623c40f483cba30d1`.

No blocking findings. The seven reviewed files match the candidate tree
byte-for-byte. The implementation satisfies AC1-AC5 and fits the existing M0
preservation and credential-free validation architecture.

The M0 handoff precondition is established: `TASK-260715-14lk3y` is `done`, its
review checklist is accepted, and its task-scoped preservation contract was
read during this review. Future user/coexistence migration remains owned by M4
`TASK-260715-35nc5m`; release identity, packaging, entitlement, and data
migration remain owned by M5 `TASK-260715-1tzaed`.

## Independently rerun by this reviewer

| Gate | Exit | Result / evidence |
| --- | ---: | --- |
| Real source/PBX/Debug+Release product isolation CLI | 0 | `guard-real-products.log`; report `reviewer-migration-isolation.json` |
| Migration-isolation production-CLI negative suite | 0 | Baseline plus seven named rejected mutations in `negative-suite.log` |
| Narrowed release-marker mutant | 1, expected | Removing only `ReluxProxy.dmg` admitted exactly the named release-substitution attack; seven other rows passed (`release-marker-mutant.log`) |
| Generated host Debug clean build | 0 | Reviewer-scoped products/DerivedData; `generated-host-debug-clean-build.log` |
| Generated host Release clean build | 0 | Reviewer-scoped products/DerivedData; `generated-host-release-clean-build.log` |
| Generated provider Debug clean build | 0 | Reviewer-scoped products/DerivedData; `generated-provider-debug-clean-build.log` |
| Generated provider Release clean build | 0 | Reviewer-scoped products/DerivedData; `generated-provider-release-clean-build.log` |
| Legacy v0.1.0 clean test build | 0 | 4 tests, 0 failures; isolated scratch path; `legacy-clean-test.log` |
| Legacy v0.1.0 clean release build | 0 | Isolated scratch path; `legacy-clean-release-build.log` |
| Accepted M0 preservation guard | 0 | Signed tag, 14 pinned files, identities, release entries, and reserved paths; `legacy-preservation-review.log` |
| Existing legacy mutation suite | 0 | Baseline plus seven rejected mutations; `legacy-negative-review.log` |
| Black / ShellCheck / Python compile / exact-delta whitespace | 0 / 0 / 0 / 0 | `black-check.log`, `shellcheck.log`, `pycompile.log`, `diff-check.log` |
| Candidate blob comparison | 0 | All seven working files equal the supplied candidate-tree blobs |

One reviewer-only evidence command exited 1 before performing a comparison
because a zsh loop variable named `path` overwrote `PATH`. It was recorded in
`candidate-match-attempt-01.log` and rerun with `file_rel`; the corrected exact
candidate comparison exited 0. This was a harness-command error, not a product
or test failure.

Final `task-board validate` returned process exit 0 but reported
`PARENT_STATUS_MISMATCH`: the owning Story is stored as `backlog` while its
child aggregate is `to-review`. This is recorded as an orchestrator-owned board
state anomaly and is not described as clean validation; it does not change the
accepted CR verdict.

## Accepted from producer-attached evidence

The producer outcome `TASK-260715-3qqbbm_results.md` and machine report
`TASK-260715-3qqbbm_migration-isolation-report.json` were inspected. This
review accepts their already-attached evidence for the full 514-test SwiftPM
suite, M1 focused runtime/ownership suites, existing unsigned macOS target-test
and linkage validation, provider-graph adversarial suite, legacy ad-hoc
universal app/DMG packaging, and package dependency projections. Those broad
checks were not rerun in full by this reviewer; the task-specific clean builds,
legacy test/release paths, collision/cross-link attacks, and linters listed
above were rerun independently.

## Gate assessment

Production call site: `scripts/validate-credential-free.sh` step
`migration-isolation` invokes `scripts/check-migration-isolation.py:main` after
generated host/provider validation and before the legacy SwiftPM test/release
builds. The check fails closed on unreadable required inputs and covers the
legacy byte inventory, exact target dependencies, generated identities,
defaults and Keychain namespaces, launch behavior, release entries, PBX
identity, and both built configurations. The negative suite drives that same
CLI, not a fake helper. The narrowed-marker mutant proves the release bound
rather than merely deleting the whole gate.

The migration boundary is most clearly represented by the focused comparison
table in `docs/migration-isolation.md`; no additional architecture diagram is
needed for this two-lane identity inventory.
