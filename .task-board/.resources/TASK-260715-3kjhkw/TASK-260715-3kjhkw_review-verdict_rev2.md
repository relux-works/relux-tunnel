# TASK-260715-3kjhkw review verdict — revision 2

Verdict: accepted for Change Request CR-TASK-260715-3kjhkw-2 revision 2, candidate tree f0e51b901cc378b88994e4bf2c2db0bc4f013047.

No blocking implementation, architecture, validation, or test finding remains. Revision 2 fixes the prior warning-floor defect at MemoryWatermarkController.observe -> nextState by clamping one-step recovery to the strongest entry signal in the same observation. A warning may move Critical to Pressure but cannot reduce Pressure to Soft.

Independent reviewer evidence:
- Staged delta equals the candidate tree; git diff --cached --check exit 0.
- MemoryWatermarkControllerTests: exit 0, 13 tests.
- Negative mutant in a task-scoped .temp copy: removing max(recovered, entry.state) makes warningCannotRecoverBelowPressure fail with exit 1 and two issues, proving the production gate rejects Pressure -> Soft recovery during a warning.
- SSHReceiveWindowBudgetPolicyTests: exit 0, 11 tests.
- LibSSH2WindowPolicyAdapterTests: exit 0, 1 test.
- make validate-core: exit 0, 519 tests in 43 suites with 25 pre-existing known ReluxNIOSSH-unavailable issues; post-test swift build exit 0.
- Swift format lint: exit 0. Core boundaries: exit 0.
- Generic iOS Simulator ReluxTunnelCore build: exit 0, BUILD SUCCEEDED.
- Sampler evidence: 256 macOS samples, 0.000360833 seconds total and 0.000012833 seconds maximum.
- Direct macOS SDK probe rejects os_proc_available_memory as unavailable, exit 1 as expected, validating the explicit unavailable state.
- task-board validate returned exit 0 while reporting the already-recorded parent aggregation mismatches for this Story and unrelated STORY-260715-1y04r0; this is not a candidate failure.

The observation contract, fresh iOS advisory sampling, validated thresholds, deterministic actor serialization, hysteresis, stale and unavailable handling, cadence and history bounds, overflow behavior, warning recovery, configuration replacement, concurrency, and fixed-cardinality redacted metrics satisfy the acceptance criteria.

Full reviewer logs are under .temp/TASK-260715-3kjhkw-review/. The reviewer made no repository changes.

Board lifecycle note: the first accept_cr attempt referenced the pre-existing TASK-260715-3kjhkw_review-verdict.md and was refused with change_request_evidence_missing because that filename predated this run. This newly added revision-specific outcome supplies manifest-owned evidence without deleting prior review history.