# TASK-260720-1qhxqa review verdict — CR revision 6

Verdict: CHANGES REQUESTED. Route the task to `to-dev`. Do not call
`accept_cr` for revision 6.

## Blocking finding

The revision-6 implementation adds two distinct production-byte checks in
`scripts/validate-m0-production-bindings.py`: selected patch bytes at lines
573–575 and every selected public-header slice's bytes at lines 599–601. The
checked-in negative tests do not exercise either branch. Lines 329–340 mutate
only the patch manifest's stored digest, and lines 342–354 mutate only the
native manifest's stored header digest. Those tests still reject if the actual
file-byte comparisons are deleted, so they do not prove the new bounds at the
production call site.

This violates the task's explicit negative-evidence contract and the DoD item
requiring relevant tests for changed gating behavior. Add production-entry
regressions that alter one byte of the selected patch while leaving its accepted
lock intact, and alter one byte of a required `libssh2.h` slice while leaving
its accepted lock intact. Each must require nonzero process exit, stable row
`REPOSITORY-SSH-PIN`, and `productionCompositionPermitted=false`.

Independent narrowing attacks confirm the implementation currently behaves
correctly: the patch-byte mutant produced `make` exit 2 and detail `selected
patch bytes drift`; the header-byte mutant produced `make` exit 2 and detail
`public-header bytes drift for macos-arm64_x86_64`. The gap is durable shipped
regression coverage, not current runtime behavior.

## Exact candidate and authority evidence

- Reviewed CR `CR-TASK-260720-1qhxqa-6`, revision 6, base
  `b3422b05226253a17676b9b84c764071fe3dbe74`, candidate tree
  `7e25e4dae58039d09a4edf58c3fb5b1aedf8d6fc`.
- The independently generated binary diff is byte-identical to
  `TASK-260720-1qhxqa_change-request_rev6.patch`; SHA-256
  `da1c252e5ed2ec94f3091ad659a11c99cd035786c7b323439f9e9485fbbe0fa4`.
- Candidate machine manifest, owner outcome attachment, and
  `TASK-260715-3ejhyy` sole-consumer precondition are byte-identical; SHA-256
  `39b3428d6cf778fa6b682bb0853a177d6b85f03b8062309f0d198dcdfd49fae6`.
- `TASK-260715-nphtib_results.md`:
  `63faf7a35b1c3554bbe5c23def6edddb9bc8454d40bfc1fb94071e1461f23ddd`;
  accepted by `TASK-260715-nphtib_final-delta-review-results.md`:
  `d9278fb1baec644d27c2fbd4a263758dee8f583b796f9c8ae7cc5e2e80985679`.
- `TASK-260715-2jatnd_m0-bridge-hev-decision-adr.md`:
  `f2dc587541386cdc5eb7e10328adda21b8bbba3af32d5c722e62616a2abca173`;
  accepted by `TASK-260715-2jatnd_review-verdict-rev2.md`:
  `73de6f96adadbd4b9469e26d760c3edbe6bd56120b97ab4f3d752812d3df8246`.
- `TASK-260715-1gjxer_ssh-engine-selection-adr.md`:
  `f1d2369a694c7a6f6642cff4324b46a6727b7a6aef3d65a9cf13ee8821ea2282`;
  accepted by `TASK-260715-1gjxer_results.md`:
  `3583369777a0d897ef2a156ddddeea92cd15b5c0b3b290582015667a37044a31`.
- `TASK-260715-30zng6_runtime-contract.md`:
  `c13bbb54a455da89f3e66121c81532b298eab73fac30b6d14d2e2df43fff8851`;
  accepted by `TASK-260715-30zng6_review.md`:
  `7a64ad098efd8cff52e0c6d144763b29e4d4008aab8e0967ce805c6134b0b756`.
- All four authority tasks are reviewer-terminal `done`, all eight exact
  resources remain declared, and no conflicting accepted replacement was
  identified. Every manifest supersession object is exactly `current` with
  `supersededBy=null`.
- The normalized graph, packet/HEV pins and values, selected SSH adapter and
  pins, algorithms, windows, rekey envelope, lifecycle, capabilities, notices,
  maintenance obligations, revalidation triggers, eight M1 compatibility rows,
  and sole-consumer/failure contract match the accepted resources and runtime
  contract without promoting deferred values.

## Fresh validation

- `make m0-bindings-test`: exit 0; 20 tests passed.
- `make m0-bindings-check TASK_BOARD_RESOURCES="$TASK_BOARD_DIR/.resources"`:
  exit 0; no failures; permission true for the unchanged accepted candidate.
- Patch-byte production mutant: `make` exit 2; permission false;
  `REPOSITORY-SSH-PIN`.
- Public-header-byte production mutant: `make` exit 2; permission false;
  `REPOSITORY-SSH-PIN`.
- `make check-native-dependencies`: exit 0.
- Python compile: exit 0. Exact CR `git diff --check`: exit 0.
- `task-board validate`: process exit 0 but reports two retained
  `PARENT_STATUS_MISMATCH` rows (`STORY-260715-1zzt0c` and owning
  `STORY-260715-1y04r0`); this is recorded as an anomaly, not a clean board.

No repository file was changed by the reviewer. No VPN, route, DNS, SSH session,
signing, installation, activation, commit, rebase, merge, or branch switch was
performed.
