# TASK-260720-1qhxqa review verdict — CR revision 2

Verdict: CHANGES REQUESTED. Route the task to `to-dev`; do not accept
`CR-TASK-260720-1qhxqa-2` revision 2.

## Exact candidate reviewed

- Base OID: `b3422b05226253a17676b9b84c764071fe3dbe74`.
- Candidate tree OID: `f7c13ed9cb885ac8a8352b8616d40ba17ba81dea`.
- Patch SHA-256: `2d53ac9a19dfb985266973f680a15063cf24fb0a8403a1ece0fd8f23ba9dd7b7` (matched).
- All seven changed worktree files matched their candidate-tree blob OIDs.
- `git diff --check base candidate` exited 0.

## Blocking finding F1 — extra production dependency bypasses the exact graph gate

The production repository check in
`scripts/validate-m0-production-bindings.py::verify_repository` calls
`require_tokens`, which proves only that required dependency tokens occur in
each target block. It does not prove the exact dependency closure asserted by
the manifest and accepted generated-project outcome.

The reviewer copied the exact candidate into a task-scoped mutant repository
and added this unauthorized direct dependency to the production provider target:

```swift
.package(product: "ReluxTunnelCore")
```

`ReluxProxyMacTunnel` then directly consumed both
`ReluxTunnelMacOSAdapter` and `ReluxTunnelCore`, contradicting the accepted
binding that the provider directly consumes only the macOS adapter plus the
verified relay resource. The actual production entry point was driven:

```text
make -C .temp/review-TASK-260720-1qhxqa/graph-mutant m0-bindings-check \
  TASK_BOARD_RESOURCES="$TASK_BOARD_DIR/.resources"
```

Actual result: exit 0, empty `failures`, and
`productionCompositionPermitted=true`. Expected result: nonzero exit with a
stable repository-graph failure row and permission false. This is a narrowing
mutant, not a delete-only mutant, and demonstrates that an incompatible M1
generated dependency graph can retain the production permit. It violates AC2
exact project-graph/dependency-direction binding, AC3 internal/runtime
compatibility gating, and AC4 deterministic fail-closed validation.

Required rework:

1. Parse or otherwise normalize each protected target's direct dependency and
   resource lists and compare them for exact equality, rejecting missing,
   duplicate, and extra entries. Substring presence is insufficient.
2. Add a production-entry-point negative test that injects an extra provider
   dependency and requires exit 1 plus `productionCompositionPermitted=false`.
3. Add equivalent extra-dependency mutants for the macOS adapter, native
   adapter, and selected SSH adapter so every asserted direct closure is exact.

## Accepted-resource and baseline evidence

Independent SHA-256 recomputation matched all eight bound board resources:

- generated outcome/verdict: `63faf7a35b1c3554bbe5c23def6edddb9bc8454d40bfc1fb94071e1461f23ddd` / `d9278fb1baec644d27c2fbd4a263758dee8f583b796f9c8ae7cc5e2e80985679`;
- packet/HEV outcome/verdict: `f2dc587541386cdc5eb7e10328adda21b8bbba3af32d5c722e62616a2abca173` / `73de6f96adadbd4b9469e26d760c3edbe6bd56120b97ab4f3d752812d3df8246`;
- SSH outcome/verdict: `f1d2369a694c7a6f6642cff4324b46a6727b7a6aef3d65a9cf13ee8821ea2282` / `3583369777a0d897ef2a156ddddeea92cd15b5c0b3b290582015667a37044a31`;
- M1 runtime contract/verdict: `c13bbb54a455da89f3e66121c81532b298eab73fac30b6d14d2e2df43fff8851` / `7a64ad098efd8cff52e0c6d144763b29e4d4008aab8e0967ce805c6134b0b756`.

All four authority tasks were `done`; exact outcome/verdict resources remained
declared; dates and current/supersession claims matched the accepted lifecycle
records. The repository manifest, owning board attachment, and sole-consumer
precondition attachment were byte-identical at SHA-256
`39b3428d6cf778fa6b682bb0853a177d6b85f03b8062309f0d198dcdfd49fae6`.
`TASK-260715-3ejhyy` declares that file as its sole M0 precondition and remains
blocked pending this task.

Baseline validation was independently rerun:

- `make m0-bindings-check ...`: exit 0, permission true for the unmodified candidate;
- `make m0-bindings-test`: exit 0, 12/12 tests passed;
- `python3 -m py_compile ...`: exit 0;
- `task-board validate`: process exit 0 while printing two retained
  `PARENT_STATUS_MISMATCH` rows, including owning Story stored `to-dev` versus
  child aggregate `reviewing`; this was not represented as clean validation.

The first candidate-identity helper attempt was invalid because it assigned to
zsh's special `path` array and thereby removed `git` and `sha256sum` from
`PATH`. Its failure log is retained but not used. The corrected helper used a
safe variable name, matched every blob and the patch digest, and exited 0.

The reviewer made no candidate repository change, supplied no `commit_ack`, and
did not call `accept_cr`.
