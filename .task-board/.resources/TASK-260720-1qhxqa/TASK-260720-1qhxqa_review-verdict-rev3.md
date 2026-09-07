# TASK-260720-1qhxqa review verdict — CR revision 3

Verdict: CHANGES REQUESTED. Route the task to `to-dev`. Do not accept
`CR-TASK-260720-1qhxqa-3` revision 3.

## Blocking finding

`scripts/validate-m0-production-bindings.py` can be bypassed by a commented
Swift/Tuist target declaration. `target_block()` uses a regular expression over
raw source and does not distinguish code from comments. A narrowing mutant
therefore added a real unauthorized direct dependency from
`ReluxProxyMacTunnel` to `ReluxTunnelCore`, while placing this harmless comment
before the real target:

```swift
// .target(name: "ReluxProxyMacTunnel", resources: [.folderReference(path: verifiedRelayBundleInput)], dependencies: [.package(product: "ReluxTunnelMacOSAdapter")])
```

The production validator selected the commented decoy, ignored the real target
closure, returned exit 0, emitted no failures, and set
`productionCompositionPermitted=true`. The actual Tuist target still contained
the extra `ReluxTunnelCore` dependency. Evidence:

- `TASK-260720-1qhxqa_review-comment-bypass-Project.swift`
- `TASK-260720-1qhxqa_review-comment-bypass-report.json`
- `TASK-260720-1qhxqa_review-comment-bypass.log`

This violates AC3 and AC4 and the negative-evidence contract: production
composition can remain permitted with an incompatible generated target graph.
The production call site exercised was
`scripts/validate-m0-production-bindings.py`, the validator invoked by
`make m0-bindings-check` before the future `TASK-260715-3ejhyy` production
factory may compose concrete dependencies.

Required rework:

1. Resolve the real Swift/Tuist target declaration with a lexical/parser-backed
   method that ignores comments and string contents, or validate the generated
   Tuist graph rather than raw-source regex matches.
2. Reject duplicate/ambiguous target declarations instead of selecting the
   first textual match.
3. Add a production-entry negative test containing the commented decoy plus a
   real extra dependency; it must exit 1 at `REPOSITORY-GRAPH` with
   `productionCompositionPermitted=false`.

## Accepted-resource and M0 verification

The exact eight bound resource digests were independently recomputed through
board-materialized bytes and matched the manifest:

- `TASK-260715-nphtib_results.md` — `63faf7a35b1c3554bbe5c23def6edddb9bc8454d40bfc1fb94071e1461f23ddd`
- `TASK-260715-nphtib_final-delta-review-results.md` — `d9278fb1baec644d27c2fbd4a263758dee8f583b796f9c8ae7cc5e2e80985679`
- `TASK-260715-2jatnd_m0-bridge-hev-decision-adr.md` — `f2dc587541386cdc5eb7e10328adda21b8bbba3af32d5c722e62616a2abca173`
- `TASK-260715-2jatnd_review-verdict-rev2.md` — `73de6f96adadbd4b9469e26d760c3edbe6bd56120b97ab4f3d752812d3df8246`
- `TASK-260715-1gjxer_ssh-engine-selection-adr.md` — `f1d2369a694c7a6f6642cff4324b46a6727b7a6aef3d65a9cf13ee8821ea2282`
- `TASK-260715-1gjxer_results.md` — `3583369777a0d897ef2a156ddddeea92cd15b5c0b3b290582015667a37044a31`
- `TASK-260715-30zng6_runtime-contract.md` — `c13bbb54a455da89f3e66121c81532b298eab73fac30b6d14d2e2df43fff8851`
- `TASK-260715-30zng6_review.md` — `7a64ad098efd8cff52e0c6d144763b29e4d4008aab8e0967ce805c6134b0b756`

All four authority tasks were `done`; each exact accepted outcome and verdict
resource remained declared. The manifest recorded all four supersession states
as `current` with no successor. The accepted generated graph, packet/HEV pins
and values, SSH selection/pins/algorithms/windows/rekey/lifecycle obligations,
licenses/notices/maintenance, revalidation triggers, deferred rows, and M1
runtime-contract constraints matched the reviewer-accepted resource contents.
The sole-consumer precondition manifest attached to `TASK-260715-3ejhyy` was
byte-identical to the repository manifest. `TASK-260715-3ejhyy` remains blocked,
so no future production factory call site was claimed as already implemented.

## Other independent gates

- Exact CR patch SHA-256: `63fbd075860a0f5f92cac92f5631c6d1b9d499cc5f744bef95b58d61a66e4537`;
  independently generated candidate diff was byte-identical. `git diff --check`
  exited 0.
- `python3 -m unittest -v scripts.tests.test_m0_production_bindings`: exit 0,
  14 tests passed.
- Unmodified `make m0-bindings-check`: exit 0 with permit true and no failures.
- `python3 -m py_compile` for validator and tests: exit 0.
- Narrowing comment-bypass mutant: validator exit 0 with permit true. This is
  the blocking negative result; a green baseline and positive tests cannot
  override it.

The reviewer made no repository changes and supplied no `commit_ack`.
