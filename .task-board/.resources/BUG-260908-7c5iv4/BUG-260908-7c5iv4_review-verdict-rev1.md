# Independent review: CR-BUG-260908-7c5iv4-1 revision 1

Verdict: ACCEPT. No blocking finding in the scoped boundary repair. Acceptance is for immutable candidate tree ff711bcf8335bd2394bd06e38e6bbb514fd58d63 against b3422b05226253a17676b9b84c764071fe3dbe74, not hosted delivery or determinism. Parent must route the bound developer/implementer for the non-final leaf checkpoint. Reviewer performed no product edits, commits, branch changes, integration, hosted updates, tool installation/source edits, VPN actions, subagents, or successors.

## Scope and architecture

Reviewed all 11 changed paths. All current worktree bytes equal the immutable tree. CI calls the extracted board CLI and its tests; only root .activity and .resources are excluded, while genuine incomplete elements under other hidden or nested activity directories fail. SnapshotDiff.compare checks all three URLs before I/O, constructs file URLs explicitly, and retains existing image and artifact behavior. Scanner adds only filePath to the existing inline fileURLWithPath lexical constructor boundary; it does not exempt a directory or test-support file. Arbitrary URL variables, string constructors, and trailing expression transformations remain rejected. It is a conservative lexical scanner, not type resolution/data-flow proof; shadowed Foundation symbols and arbitrary language obfuscation are outside this repair's attestation.

The validation fixture correction matches the accepted runtime dependency and is already present at PR6 head. No generated scheme or runtime/protocol change is introduced. README documents both tools, LOGBOOK preserves the failure/retry limitation.

## AC coverage

**2 of 5 AC rows driven by named candidate tests; 3 of 5 explicitly stated process/environment bounds.** Tests are included in the immutable CR tree, pending the producer-owned signed checkpoint; reviewer cannot create their commit.

1. Automated: CI Check board structure -> scripts/check_board_structure.py::main -> check. BoardStructureTests.test_activity_and_resource_payloads_are_not_elements, test_incomplete_element_fails, test_unknown_hidden_directory_is_not_exempt, test_nested_activity_name_is_not_exempt, test_empty_or_missing_board_fails execute the actual CLI and assert exits/diagnostics.
2. Automated: relay_supply_chain.audit -> scan_runtime -> forbidden_runtime_surface -> swift_contents_of_surface. RelaySupplyChainTests.test_checked_in_metadata_passes_clean_audit, test_snapshot_support_local_loads_pass_actual_runtime_scan, test_snapshot_support_network_mutants_preserve_file_tokens_and_fail, test_runtime_scan_rejects_string_constructor_even_with_file_path_token exercise the production audit/scanner. SnapshotDiffSupportTests.nonFileURLs, matchingLocalImages, mismatchArtifacts drive SnapshotDiff.compare; HTTP/HTTPS/FTP/data are rejected at each of three URL positions before I/O.
3. Process bound: independently reran clean exact PR 87451b53960ceabe88a01c44c287fee7f9ebf386 before/after real CI board block and make relay-supply-chain-audit; retained separate full-suite producer evidence for old-main candidate and PR composition. No claim of hosted execution.
4. Process bound: independently verified signatures on 87451b53960ceabe88a01c44c287fee7f9ebf386 and 6e8a19885f99ec9837054e0b3e07e7d0c1ffcd51; preserved objects and all managed-worktree bytes. Acceptance binds the immutable CR; publication/landing is not this role's action.
5. Environment bound: completed before 2026-09-08 04:59 Asia/Tbilisi, with no VPN, successors, subagents, tool source patches or installs.

## Independent execution

- Tool readiness: installed task-board status/read operations, git --version, python3 --version, swift --version succeeded; versions retained.
- 29 board/supply-chain Python tests: exit 0 in managed candidate whose 11 paths were verified byte-identical to immutable CR.
- python3 scripts/tests/test_pr6_boundary_mutants.py from a git archive of the immutable tree: exit 0. All three production positive runs passed; all three weakened-gate runs exited 1 with their named failures. Board mutant admits exactly .hidden. Scanner mutant additionally admits referenceURL and is caught by token-preserving network variants. Swift mutant retains isFileURL but admits HTTP; compiled behavioral suite fails nonFileURLs in all three positions while the file constructor prevents network access. This is not delete-only or grep-only evidence.
- Clean exact PR before repair: actual original CI board block exit 1 (activity IDs misclassified), make relay-supply-chain-audit exit 2 (SnapshotDiff Foundation Data URL loader).
- Clean exact PR plus candidate: actual repaired CI board block exit 0 (5 tests, 412 elements), make relay-supply-chain-audit exit 0, 29 board/supply-chain Python tests exit 0.
- git diff --check base candidate: exit 0; strict swift-format lint both changed Swift files: exit 0; Python py_compile changed/new scripts: exit 0.

The first scratch composition script exited 1 because git merge-file reported a LOGBOOK append conflict; its log is preserved. A second scratch-only composition explicitly appends the candidate LOGBOOK addition to PR6's existing log and merges README, preserving both histories; code/workflow/test files are exact candidate bytes. This resolves diagnostic composition, not the parent's later integration transaction. Initial check_item dry-run used unsupported index argument and was refused without mutation; scoped schema identified the correct 1-based item argument.

## Evidence accepted from the producer (not rerun as full suites)

Read the four required TASK-260830-1x524u delivery resources and BUG developer results, identity/lint logs, and validation.zip. Inspected separate base and PR-composition summaries, environment, and original failed Swift transcript.

Old-main candidate full credential-free suite passed (496 Swift tests, 25 known issues). First full PR-composition attempt failed: make exit 2 / Swift exit 1; HEVBridgeIntegrationTests.swift:178 observed maximumOutstandingReadCount 0 instead of 1; LibSSH2AdapterIntegrationTests.swift:579 observed writeCallCount 0. Those files are unchanged by this repair and between base and PR head. Sequential full PR-composition retry passed (516 Swift tests, 25 known issues), including Shared Runtime migration-isolation gates, builds, packaging and legacy checks. The first failure remains a failure. Scheduling interference is unproven; a single successful retry does not establish determinism or green hosted CI. Acceptance of this scoped repair does not waive future required checks.

Native Linux/Intel, physical device/release/signing/notarization and hosted green status are not independently attested here. SnapshotDiff uses AppKit, so its bounded compiled behavioral proof runs on macOS.

## Checklist disposition and evidence

Implementation fits AC and architecture; relevant targeted tests and mutants pass; gating behavior was attacked through production entry points. The conditional rejection-routing checklist is satisfied by recording this explicit acceptance verdict and using accept_cr instead of done. All producer checklist evidence was reviewed with the limitations above.

BUG-260908-7c5iv4_review-evidence-rev1.zip contains independent commands, real exits, initial scratch conflict, successful retry, mutant output, integrity hashes, lint/readiness, diff shape and the scratch reproduction script. Existing BUG-260908-7c5iv4_validation.zip remains the source of the full-suite failure/retry evidence. No hosted landing authorization is inferred from local results.
