## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:16:33Z

## Last Update
2026-07-28T04:20:51Z

## Blocked By
- TASK-260715-29ws8l
- TASK-260715-lovbdz
- TASK-260728-7ii1xz

## Blocks
- TASK-260715-3t2v9w
- TASK-260715-3cv3r4
- TASK-260715-28bwf4
- TASK-260715-1yxpqv

## Checklist
- [ ] Implement atomic versioned profile loading and exhaustive validation
- [ ] Run canonicalization corruption version and secret-exclusion tests
- [ ] Attach task-scoped schema and loader evidence

## Notes
2026-07-28 TASK-260728-7ii1xz decided the macOS credential transport and found a secondary blocker for this task. REVISE: the App Group container is NOT shared between the user-context host and the root provider on macOS - containerURL resolves relative to the caller home and the provider home is /private/var/root, verified root-private with ls exit 1, and two shipping providers carry an absolute-path exception for exactly that tree. The snapshot must arrive through providerConfiguration, already the accepted M1 channel bounded to 4 KiB, not through an App Group file. AC3 atomicity is then satisfied by NE configuration delivery, and size-bound tests target the 4 KiB providerConfiguration limit. Corroborated not directly observed; TASK-260715-9yp8to check V2 closes it. See TASK-260728-7ii1xz_macos-credential-transport-decision.md section 6.

## Precondition Resources
(none)

## Outcome Resources
(none)
