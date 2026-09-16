# BUG-260908-7c5iv4 — developer evidence

Status: ready for developer handoff to independent review; no acceptance or hosted landing claimed.

## Scope and identity

Managed Story base is `b3422b05226253a17676b9b84c764071fe3dbe74`, equal to freshly advertised and fetched remote main. PR 6 still advertises `87451b53960ceabe88a01c44c287fee7f9ebf386`. Both PR head and accepted runtime commit `6e8a19885f99ec9837054e0b3e07e7d0c1ffcd51` verify with the configured human signature. No commits, branch switches, rebases, or integration were performed on the managed Story branch. Parent owns independent review and hosted sequencing.

The diagnostic detached worktree under `.temp/BUG-260908-7c5iv4/pr-composition` starts at that exact PR head. Only the task patch is overlaid; Shared Runtime code and existing signed objects are preserved. The accepted validation-contract fixture correction is already present there and contributes no composition diff. The Story-base candidate includes that exact correction, after reproducing its missing-UI-scheme failure (exit 1); no generated scheme was fabricated.

## Repair

- CI invokes `scripts/check_board_structure.py` and its tests. Only root `.activity` and `.resources` stores are excluded. Unknown hidden directories and nested directories named `.activity` remain checked for genuine elements.
- SnapshotDiff now rejects non-file reference, failed-image, and output URLs before any I/O. Each image read constructs `URL(filePath:)` inline; scanner support adds only this Foundation file-URL initializer alongside the existing `fileURLWithPath:` form. No scan root, extension, policy, or test-support file is exempted.
- The small production SnapshotDiff edit is necessary to establish an actual local-file boundary. A scanner-only test-support exclusion would admit the old public API's arbitrary URL loader.
- The scanner remains a conservative lexical surface checker, not a Swift type checker or complete data-flow proof. Variable URL arguments and transformed constructor expressions remain rejected even when a caller could prove them local. This repair does not attest that arbitrary language-level obfuscation or shadowed Foundation types are impossible.

## Acceptance coverage

**2 of 5 AC rows driven by named candidate tests; 3 of 5 are explicitly stated process/environment bounds.** All tests are included in the uncommitted managed candidate for immutable CR publication; this producer must not create a commit itself.

| AC | Production call site and evidence |
| --- | --- |
| 1 — automated | Actual CI run block → `check_board_structure.py::main` → `check`. `BoardStructureTests.test_activity_and_resource_payloads_are_not_elements`, `test_incomplete_element_fails`, `test_unknown_hidden_directory_is_not_exempt`, `test_nested_activity_name_is_not_exempt`, `test_empty_or_missing_board_fails`. Tests execute the production CLI subprocess and assert exit and diagnostics. |
| 2 — automated | `relay_supply_chain.audit` → `scan_runtime` → `forbidden_runtime_surface` → `swift_contents_of_surface`. `RelaySupplyChainTests.test_snapshot_support_local_loads_pass_actual_runtime_scan`, `test_snapshot_support_network_mutants_preserve_file_tokens_and_fail`, `test_runtime_scan_rejects_string_constructor_even_with_file_path_token`. Swift `SnapshotDiff.compare` is driven by `SnapshotDiffSupportTests.nonFileURLs`, `matchingLocalImages`, and existing `mismatchArtifacts`. Non-file tests cover HTTP, HTTPS, FTP, data in all three argument positions, requiring the exact refusal before nonexistent local-file I/O. |
| 3 — process bound | Clean exact-head archives reproduce the old CI board block and actual `make relay-supply-chain-audit`; separate clean detached PR-head composition runs the repaired real CI step and relay gates. Exact commands/exits and full-suite evidence are recorded separately from old-main evidence. This is an execution/revision assertion, not an automated test of hosted CI. |
| 4 — process bound | Fresh remote identities and `git verify-commit` evidence; scoped patch and managed handoff publish an immutable CR without manually committing, rewriting, or updating hosted delivery. Independent review belongs to the parent. |
| 5 — environment bound | This run must stop before 04:59 Tbilisi. No successors/subagents, VPN install/config/connect, reusable-tool source edits, or global tool installation. Existing checksum-pinned Go/Syft archives were copied into task-local build caches and the repository's mandatory bootstrap verified/re-extracted them. Existing Tuist 4.202.5 was reused; new worktree mise configs were explicitly trusted. No hosted green-check claim is made. |

## Narrowing and token-preservation proofs

`python3 scripts/tests/test_pr6_boundary_mutants.py` exits 0 only after each named regression passes on production and fails on its corresponding narrowed gate:

1. Board exclusion stays present but additionally admits exactly `.hidden`; `test_unknown_hidden_directory_is_not_exempt` fails.
2. Scanner remains present but additionally admits the URL variable `referenceURL`; `test_snapshot_support_network_mutants_preserve_file_tokens_and_fail` fails. Source attack fixtures retain `filePath` and `isFileURL`, allow HTTPS in the guard, and replace the actual loader with an arbitrary/network URL expression. The audit still rejects them before any execution.
3. Swift guard retains `isFileURL` and its error but additionally admits HTTP; the compiled production `SnapshotDiff.compare` runs all three behavioral tests and `nonFileURLs` fails with the wrong-error diagnostic. The file constructor stays present, so this mutant performs no network access. This is behavioral execution, not a grep-only assertion.

## Reproduction and validation

All failure reproductions below were rerun by this producer, not merely accepted from RUN-260907-765f2f. Prior task evidence was read as provenance/context only.

| Tree | Command | Exit/result |
| --- | --- | --- |
| Clean PR archive, before | Execute original Python `Check board structure` block from exact-head `ci.yml` | 1; `.activity` IDs misclassified |
| Clean PR archive, before | `make relay-supply-chain-audit` | 2; Foundation Data URL loader in SnapshotDiff |
| Clean old-main archive, before | Same original board block | 0; 411 elements, no activity failure |
| Clean old-main archive, before | `make relay-supply-chain-audit` | 2; same SnapshotDiff failure |
| Story base plus repair | Actual repaired CI board run block | 0; 5 tests, 411 elements |
| PR head plus repair | Actual repaired CI board run block | 0; 5 tests, 412 elements |
| PR head plus repair | `make relay-supply-chain-audit relay-supply-chain-test relay-toolchain-check relay-toolchain-negative-test` | 0; audit, 24 tests, pins and missing-input gates pass |
| Story base plus repair | `swift test --filter SnapshotDiffSupportTests` | 0; 3 Swift Testing tests |
| Story base plus repair | `python3 scripts/tests/test_pr6_boundary_mutants.py` | 0; all three narrowing mutants killed |
| Final task source | `git diff --check`, Python `py_compile` for changed/new scripts, `xcrun swift-format lint --strict` for both Swift files | 0 each |

Full credential-free suite outcomes are recorded below. The initial mise inspection failed because the isolated config was untrusted; `mise trust` resolved it, and installed Tuist was verified. An initial guessed `git show` path failed (exit 128); the actual SnapshotDiff path was then read. These failures are not reported as passing checks.

## Full-suite observation (first runs)

- Story-base `LEGACY_ROOT=... make credential-free-validate`: exit 0. All repository steps ran, including macOS target builds, 496 Swift tests (25 pre-existing known issues), release build, native packaging, and legacy checks/builds.
- PR-composition first full suite: make exit 2 / Swift step exit 1. Of 516 Swift tests, two unexpected failures occurred: `HEVBridgeIntegrationTests.swift:178` expected maximum outstanding reads 1, observed 0; `LibSSH2AdapterIntegrationTests.swift:579` expected positive write-call count, observed 0. The 25 known issues remain separate. The first failed log is preserved; it is not overwritten by the retry.
- Both failed test files are unchanged between old main and exact PR head and untouched by this repair. The first runs overlapped. Scheduling interference is a hypothesis, not an established cause. A sequential full PR-composition retry subsequently passed; the initial failed attempt stays failed in the record.

## Final validation and handoff

The sequential PR-composition full suite exited **0**, including all 516 Swift
tests (25 pre-existing known issues), release build, native packaging, legacy
checks/builds, and accepted Shared Runtime migration-isolation positive/negative
checks. Story-base full suite also exited **0**. No failures were waived or
reported as an external-CI incident. The two initially failing assertions did not
reproduce on the sequential full rerun; their cause remains unproven. This is a
material testing limitation to retain during independent review.

All build/validation execution reported here was rerun by this producer. No
prior runtime/build pass was substituted for current candidate verification.
Native Linux execution, native Intel execution, production signing, physical
Gate P0, notarization, and publication are **not** attested by these local macOS
checks. The actual suite explicitly reports its platform/release bounds.

`BUG-260908-7c5iv4_validation.zip` retains per-step full suite logs/environment
for base and final PR composition, the original failed PR Swift transcript,
reproduction logs, targeted/mutant logs, and inspection/readiness evidence.
The separate `BUG-260908-7c5iv4_candidate.patch` contains the complete reviewed
scope including new tests. Behavioral source, tests, and CI workflow are
byte-identical in the Story candidate and PR composition. README/LOGBOOK changes
are applied as additions preserving the accepted PR's own documentation.

The managed handoff command is the next lifecycle action after attaching this
packet and marking the evidenced checklist. Its board-recorded CR, not this
report, is authoritative for the immutable candidate identity. Parent owns
review/landing; this is ready for review, not accepted completion. All work is
preserved uncommitted in the managed Story workspace before 04:59 Tbilisi.
