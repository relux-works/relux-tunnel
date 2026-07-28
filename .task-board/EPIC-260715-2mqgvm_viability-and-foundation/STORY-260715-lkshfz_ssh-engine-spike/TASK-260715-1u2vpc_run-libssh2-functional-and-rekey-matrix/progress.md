## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:03:16Z

## Last Update
2026-07-28T01:47:11Z

## Blocked By
- TASK-260715-1ozsb6
- TASK-260715-2d3g5e
- TASK-260715-2ayxqn

## Blocks
- TASK-260715-2xx2tk
- TASK-260715-1gjxer

## Checklist
- [ ] Every libssh2 functional, compatibility, Apple, and rekey row has metadata
- [ ] Window and rekey gaps remain explicit red with reproducible evidence
- [ ] Safe mixed-traffic and cleanup evidence plus the full matrix are attached

## Notes
2026-07-28 replan round 3 (TASK-260728-3a2dnr): restored blocker TASK-260715-2ayxqn. Round 2 had removed it, which scheduled this matrix before Gate P0 existed even though its scope still requires the Gate-P0 provider smoke on the physical Apple-silicon Mac. The matrix is not re-scoped and the Apple-target rows are not weakened; it simply runs after the P0 disposition.

## Precondition Resources
(none)

## Outcome Resources
(none)
