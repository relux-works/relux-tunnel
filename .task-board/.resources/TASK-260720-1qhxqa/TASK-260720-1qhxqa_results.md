# TASK-260720-1qhxqa developer handoff — revision 10

Status: ready for independent review.

## Result

Revision 9's retained-fork fail-open is closed. The immutable M0 binding
manifest now binds the accepted ReluxNIOSSH patch disposition to the exact
checked-in retained tree through `relux.sorted-path-file-sha256/1`: 148 sorted
relative path/file-SHA-256 records, excluding only `.build` and `.swiftpm`.
The production validator recomputes the file count and tree digest before it
can return `productionCompositionPermitted=true`.

No M0 implementation, candidate selection, pin, threshold, or runtime behavior
was changed. `TASK-260715-3ejhyy` still consumes the same task-scoped manifest
as its sole M0 source; its precondition attachment is byte-identical to the
repository and owning-task outcome at SHA-256
`40333862b46b7af04cdd966ade91e8c9cc917e573c6601e26e7fa956d11ae161`.

## Reviewer finding closure

Production call chain: `Makefile` target `m0-bindings-check` ->
`scripts/validate-m0-production-bindings.py` ->
`verify_ssh_repository_pins()` -> `retained_tree_identity()`.

The durable negative mutates
`Dependencies/ReluxNIOSSH/Sources/NIOSSH/ReluxPolicies.swift` from
`maximumPayloadBytes = 32 * 1024` to `1`. The production validator returns exit
1, stable row `REPOSITORY-SSH-PIN`, exact detail
`retained ReluxNIOSSH tree bytes drift`, and
`productionCompositionPermitted=false`. The unchanged repository returns exit
0 with no failures and permission true.

## Authority and supersession audit

All four authorities remain reviewer-terminal `done`. The exact eight bound
outcome/verdict resources recompute to their manifest SHA-256 values (8/8), and
every manifest supersession record remains `{status: current, supersededBy:
null}`. The runtime contract is still exactly `m1-runtime-contract/1`; all
eight compatibility rows pass without reinterpretation.

## Validation

- `make m0-bindings-test`: exit 0; 32/32 tests passed.
- Exact retained-fork narrowing production invocation: validator exit 1 as
  required; permission false and stable failure row/detail verified.
- `make m0-bindings-check TASK_BOARD_RESOURCES="$TASK_BOARD_DIR/.resources"`:
  exit 0; manifest SHA-256
  `40333862b46b7af04cdd966ade91e8c9cc917e573c6601e26e7fa956d11ae161`,
  no failures, permission true.
- `make check-native-dependencies`: exit 0.
- Python compilation and `git diff --check`: exit 0.
- Independent resource and binding identity: 8/8 accepted resources and 2/2
  owner/consumer manifest bindings pass.
- `task-board validate`: process exit 0 with two retained
  `PARENT_STATUS_MISMATCH` rows: unrelated `STORY-260715-1zzt0c`, and owning
  `STORY-260715-1y04r0` stored `to-dev` while this developer task makes the
  aggregate `development`. This output is retained and is not called clean.

## Evidence

- `TASK-260720-1qhxqa_m0-bindings-test-rev10.log`
- `TASK-260720-1qhxqa_m0-bindings-check-rev10.log`
- `TASK-260720-1qhxqa_retained-fork-narrowing-rev10.log`
- `TASK-260720-1qhxqa_native-dependency-check-rev10.log`
- `TASK-260720-1qhxqa_resource-and-binding-digests-rev10.log`
- `TASK-260720-1qhxqa_lint-rev10.log`
- `TASK-260720-1qhxqa_board-validation-rev10.log`
