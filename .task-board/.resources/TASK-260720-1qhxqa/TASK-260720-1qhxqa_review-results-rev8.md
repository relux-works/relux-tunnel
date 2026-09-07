# TASK-260720-1qhxqa reviewer handoff — CR revision 8

Changes requested. The exact candidate and accepted-resource bindings were
verified, and the unchanged baseline gates pass, but the production composition
gate admits a one-byte mutation of the checked-in macOS HEV archive while its
artifact lock remains unchanged. The task is routed to `to-dev` with the mutant
log/report and full verdict attached.

Rerun evidence produced by this reviewer:

- 27-test production binding suite: exit 0.
- Unchanged production binding validation: exit 0, permission true.
- Native dependency verification: exit 0.
- Python compile and exact candidate diff lint: exit 0.
- HEV actual-byte mutant through the production validator: exit 0 and permission
  true, which is the blocking fail-open result.

Required correction is narrowly scoped to binding and validating actual HEV
artifact locks/bytes plus durable negative coverage. No M0 matrix rerun,
implementation reselection, or configuration tuning is requested.
