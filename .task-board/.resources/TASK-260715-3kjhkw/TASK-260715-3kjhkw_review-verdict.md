# TASK-260715-3kjhkw review verdict

Verdict: accepted for Change Request CR-TASK-260715-3kjhkw-2 revision 2, candidate tree f0e51b901cc378b88994e4bf2c2db0bc4f013047.

## Findings

No blocking implementation, architecture, validation, or test finding remains. The revision 1 warning-floor defect is fixed at MemoryWatermarkController.observe -> nextState: one-step recovery is clamped to the strongest entry signal in the same observation. A warning may move Critical to Pressure but cannot reduce Pressure to Soft.

The implementation records byte units, fixed provenance, monotonic timestamp, configuration and state generations, physical current and peak footprint, ledger current, reserved, committed and peak bytes, and a fresh advisory sample or explicit unavailable reason. Actor isolation provides one serialized state writer. Configuration validation, strict exit hysteresis, recovery acknowledgement and dwell, stale and malformed evidence handling, per-trigger cadence bounds, sampling-overrun classification, bounded ring history and fixed-cardinality metrics match the task acceptance criteria. The iOS production service calls os_proc_available_memory for each accepted observation and never retains an advisory sample. macOS explicitly reports unsupported because the SDK marks that API unavailable.

Production call sites reviewed:
- MemoryWatermarkController.observe -> nextState and SystemMemoryPlatformSamplingService.sampleCurrentProcessMemory.
- LibSSH2Transport direct-tcpip and session channel-open paths -> LibSSH2ChannelWindowAdapter.initialReceiveWindow.
- SSHReceiveWindowBudgetLedger admission, adjustment, pressure, lane and release gates.

## Independent reviewer evidence

- Candidate integrity: staged delta equals candidate tree; git diff --cached --check exit 0.
- MemoryWatermarkControllerTests: exit 0, 13 tests. Trace coverage includes inclusive Soft/Pressure/Critical entry, strict one-step recovery, stale and unavailable evidence, warning burst and warning floor, configuration replacement, 64 serialized concurrent observations, overflow, bounded history and redacted metrics.
- Negative mutant: in a task-scoped .temp copy only, removing the new max(recovered, entry.state) clamp makes warningCannotRecoverBelowPressure fail with exit 1 and two exact issues: Pressure becomes Soft and an unexpected Pressure -> Soft recovery transition appears. The reviewed repository tree was not modified.
- SSHReceiveWindowBudgetPolicyTests: exit 0, 11 tests.
- LibSSH2WindowPolicyAdapterTests: exit 0, 1 test.
- make validate-core: exit 0, 519 tests in 43 suites, 25 pre-existing known ReluxNIOSSH-unavailable issues, then swift build exit 0.
- swift format lint --recursive Sources Tests Package.swift: exit 0.
- make check-core-boundaries: exit 0.
- Generic iOS Simulator ReluxTunnelCore build: exit 0, BUILD SUCCEEDED.
- Reviewer sampler run: 256 macOS samples, 0.000360833 seconds total and 0.000012833 seconds maximum.
- Direct macOS SDK probe rejects os_proc_available_memory as unavailable, exit 1 as expected; this validates explicit unavailable rather than proxy inference.
- task-board validate returned exit 0 while reporting the already-recorded parent aggregation mismatches for STORY-260715-1zzt0c and unrelated STORY-260715-1y04r0. This board lifecycle anomaly is not a candidate code failure.

Logs are under .temp/TASK-260715-3kjhkw-review/. The reviewer made no repository changes.