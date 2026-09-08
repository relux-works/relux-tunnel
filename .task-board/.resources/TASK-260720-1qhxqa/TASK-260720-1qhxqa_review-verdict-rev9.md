# TASK-260720-1qhxqa review verdict — CR revision 9

Verdict: CHANGES REQUESTED. Route to `to-dev`.

## Blocking finding

The production gate does not bind the accepted retained ReluxNIOSSH fork patch
to the checked-in retained fork bytes. The immutable manifest records
`retainedReluxNIOSSHPatchSha256=1241622deca47f05a139998a94b2ce988935bb0e288f26cf57dc71f3d23317a4`
and the accepted ADR freezes ReluxNIOSSH as comparative evidence, but
`verify_ssh_repository_pins()` validates only its commit, archive digest, and
license digest. It never recomputes the retained fork delta/patch digest or
checks retained source bytes.

The reviewer copied the production repository fixture, narrowed
`Dependencies/ReluxNIOSSH/Sources/NIOSSH/ReluxPolicies.swift`
`maximumPayloadBytes` from `32 * 1024` to `1`, and left the accepted retained
patch SHA-256 unchanged. The production validator exited 0 with no failures and
`productionCompositionPermitted=true`. This defeats the required fork
disposition/pin binding and proves the gate can admit checked-in retained-fork
drift without revalidation. The production call chain is Makefile target
`m0-bindings-check` -> `scripts/validate-m0-production-bindings.py`; evidence is
`TASK-260720-1qhxqa_review-retained-fork-narrowing-rev9.log`.

Required rework: bind the accepted retained patch digest to a deterministic
checked-in delta or exact retained-file digest set, validate the actual bytes at
the production call site, and add a durable narrowing negative test requiring
exit 1, a stable failure row, and `productionCompositionPermitted=false`.

## Accepted evidence retained

- Exact CR revision-9 patch bytes match SHA-256
  `3287512c470bad01f68109e42c47a2921cbbf8b6573e31e6207d9a5610f758ea`;
  all seven candidate paths are byte-identical to candidate tree
  `566bb489e49781c1734a3d2443c926f1b8049591`; `git diff --check` exits 0.
- The repository manifest and owning board attachment are byte-identical at
  SHA-256 `095372d61bd2baf46a72c701e0b94ee18cece67b8d51d445b30f50e2b5c39c73`.
- All eight exact accepted outcome/verdict resources were materialized through
  `task-board resource get`; independently recomputed SHA-256 values match the
  manifest. All four authorities are currently `done`; the downstream consumer
  remains `blocked`.
- Reviewer baseline validation exits 0 with permit true, 31/31 tests pass,
  Python compilation passes, and `make check-native-dependencies` exits 0.
- `task-board validate` exits 0 while reporting two retained
  `PARENT_STATUS_MISMATCH` rows (`STORY-260715-1zzt0c` and the owning Story while
  this task is in `reviewing`); this is recorded, not described as clean.
No repository file was modified by the reviewer. No commit acknowledgement is
supplied.
