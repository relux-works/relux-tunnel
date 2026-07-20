# TASK-260715-1vv52g stop-the-line outcome

## Constraint and evidence

The exact pinned unmodified HEV revision ad7600497931205105b08367bd1b450048157e40 was rebuilt through the approved checksum-verifying hook. Its config parser unconditionally computes the effective task stack as 20480 plus the larger of tcp-buffer-size and 1500 times udp-copy-buffer-nums. The default udp-copy-buffer-nums is 10 even when socks5.udp is tcp. Therefore the requested task-stack-size 24576 is silently raised to 35480. A native executable linked to the rebuilt XCFramework proves the effective values: task stack 35480, TCP buffer 4096, UDP copy buffers 10, maximum sessions 1200.

## Failed assumption

The recorded upstream low-memory snippet implies that task-stack-size 24576 remains effective with tcp-buffer-size 4096. That is false at this pinned revision unless another UDP buffer-count value is supplied. Claiming the exact baseline while accepting the silent clamp would violate AC2.

## Viable options

1. Approve an additional injectable udp-copy-buffer-nums baseline of 2 or 1. Both keep 1500 times the count at or below the 4096 TCP buffer, so HEV retains task stack 24576. This adds a tuning input not currently authorized by the task.
2. Explicitly accept 35480 as the effective task stack and treat 24576 only as the requested input. This weakens the exact-value acceptance criterion and understates memory planning if left undocumented.
3. Patch HEV to condition the UDP buffer stack adjustment on UDP-in-UDP. This violates the unmodified-source constraint and creates a fork.

## Recommendation and required decision

Approve udp-copy-buffer-nums 2 as an explicit injectable M0 measurement input, with no HEV source patch. The exact required input is approval of that additional baseline value, or an explicit choice of option 2 or 3. Swift runtime wiring stopped before adding a compensating hidden constant.

## Work performed

- Baseline swift test passed 41 tests in 6 suites.
- The approved build-hev hook verified all pinned revisions and archive checksums, rebuilt the real Apple XCFramework, emitted notices, and passed static/extension-safety inspection.
- Probe evidence: TASK-260715-1vv52g_effective-config-probe.log.
