# TASK-260715-15vkvz rework 03

Address the P1 lost-notification race in `TASK-260715-15vkvz_review-03.md` on both Apple adapters.

- Make terminal-status observation race-safe: install the `NEVPNStatusDidChange` observer before the authoritative status check, or register then perform an authoritative recheck through an injectable seam. A transition between initial observation setup and notification delivery must still complete exactly once.
- Add deterministic iOS and macOS seam tests for terminal-before-registration, terminal-during-registration, notification-first, duplicate/late notification, cancellation, and observation retirement. Prove no callback after retirement and no false 15-second `stopTimedOut` when status is already terminal.
- Preserve the FIFO repository gate, exact signed/unsigned `NSNumber` decoding, fresh-object authority, and zero-write guarantees from prior accepted rework.

Re-run focused normal and TSan tests, full core/boundary validation, strict format/diff/board checks, and both platform builds. Attach task-scoped rework evidence and return to `to-review`; do not self-accept.
