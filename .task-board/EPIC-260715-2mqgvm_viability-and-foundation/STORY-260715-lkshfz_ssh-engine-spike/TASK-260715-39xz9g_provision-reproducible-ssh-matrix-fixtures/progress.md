## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:03:15Z

## Last Update
2026-07-28T01:47:11Z

## Blocked By
- TASK-260715-28ok1k

## Blocks
- TASK-260715-2d3g5e

## Checklist
- [ ] Server, key, algorithm, traffic, and impairment fixtures cover every matrix branch
- [ ] The real relux host is represented with least-privilege test access
- [ ] Privacy-safe fixture manifest and teardown evidence are attached

## Notes
2026-07-28 replan (TASK-260728-3a2dnr): the primary orchestrator ran a read-only BatchMode probe against the owner-authorized SSH alias and authentication succeeded without a prompt; the remote reports Darwin. No hostname, IP, username, key path, credential, or remote content was recorded. Evidence: TASK-260728-3a2dnr_relux-ssh-readiness.md. Consequence: real-host access for this task is available in the primary environment and is NOT an unevidenced human hold. This readiness probe is not conformance evidence: this task still owes raw pre-auth host-key evidence before any auth acceptance and its own fixture validation.

## Precondition Resources
(none)

## Outcome Resources
(none)
