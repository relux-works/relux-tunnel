# TASK-260715-1juybj review verdict: changes requested

Verdict: changes requested -> analysis. No human-only or external blocker exists.

## Blocking findings

1. The current admission evidence is overstated as an absolute authentication deadline. Contract lines 53-54, 95-96, and 302-316 require or imply an absolute accept-to-authentication deadline. Current `HEVSOCKSBoundary.swift` lines 437-452 set only `SO_RCVTIMEO`; Darwin documents that this timer restarts whenever additional data arrive and is therefore an inactivity timer. `authenticate` performs several independent receives and has no monotonic accept-time deadline, while reply sends have no `SO_SNDTIMEO`. A non-owned local client can therefore retain a pending slot by trickling bytes within each inactivity period. The pending ceiling bounds memory, but the source-backed absolute-deadline claim is not proved. Rework must distinguish current evidence from the M1 production decision, explicitly record the current inactivity-timeout gap, and refine `TASK-260715-b6uruh` so one monotonic accept-to-auth deadline covers all greeting/auth reads and replies without extension by progress. Add deterministic slow-trickle, wrong-credential, and stale-generation coverage to the iOS/macOS validation rows. This task remains specification-only; implementation stays downstream.

2. `TASK-260715-1juybj_flow-state.svg` is not reviewable as rendered. The task-scoped SVG produced with `!pragma layout smetana` clips state labels: Authenticated renders as `ated`, Parsing as `Pg`, Opening as `Ong`, Replying as `Ping`, Streaming as `Sting`, and the half-close labels are truncated or absent. Syntax validation alone did not catch this. Rework must use a reliable layout, re-render the task-scoped SVG, visually inspect it on an opaque background, and update validation plus hashes.

## Passing evidence retained

- The byte-level SOCKS CONNECT/reply, destination/originator, one-channel/no-migration, bounded pump, EOF/reset/cancellation/cleanup, M0 accounting, privacy metrics, and M3 seam clauses otherwise fit the accepted runtime and SSH contracts.
- Shared iOS/macOS source/linkage evidence is accurately disclosed, and the available executable rejection tests are macOS-hosted with downstream provider-sandbox rows retained.
- Independent reviewer reruns: `swift test` passed 276 tests in 25 suites; both PlantUML sources passed `-checkonly`; `task-board validate`, hashes, and `git diff --check` passed.
