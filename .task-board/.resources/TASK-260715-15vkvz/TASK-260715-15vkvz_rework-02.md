# TASK-260715-15vkvz rework 02

Address both P1 findings in `TASK-260715-15vkvz_review-02.md` without weakening zero-write or freshness guarantees.

1. Add an explicit non-reentrant repository operation gate. Actor isolation alone is insufficient because preference callbacks suspend and permit reentrancy. Deterministic tests must hold the first callback, start another ensure/enable/disable/remove/repair operation, and prove the second performs no load or mutation until the first reaches its terminal result. Include concurrent zero-manager ensure and prove only one canonical manager is saved.
2. Decode platform `NSNumber` manager versions exactly in both iOS and macOS seams. Reject/preserve without mutation fractional values and values that cannot fit `Int`; never truncate via `intValue`. Cover `NSNumber(true)`, `1.5`, `UInt64.max`, `Int.max`, and normal `Int(1)` on both seams. Preserve positive future values through a representation/error path that cannot overflow, and prove unsupported/type-confused/future values receive zero setter/save/remove calls.

Re-run focused repository and platform-seam tests, concurrency/TSan validation where applicable, full core/boundary validation, strict format/diff/board checks, and both platform builds. Attach task-scoped rework evidence and return to `to-review`; do not self-accept.
