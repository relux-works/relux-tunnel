# TASK-260720-1qhxqa review verdict — CR revision 5

Date: 2026-08-30
Role: reviewer
Change Request: `CR-TASK-260720-1qhxqa-5`, revision 5
Verdict: **CHANGES REQUESTED**
Route: `to-dev`

## Blocking finding

### F1 — Production validation admits drift in an accepted SSH binary pin

The immutable binding manifest names `patchSha256` and
`publicHeaderSha256` as accepted SSH source/binary pins. The checked-in native
dependency manifest carries the public-header lock for every XCFramework slice
and points to the patch manifest. However, `verify_repository` checks only the
libssh2 revision/archive digest and the OpenSSL tag/archive digest. It does not
compare the accepted patch digest or public-header digest against the checked-in
pin graph.

This is a production-gate bypass, not a documentation issue. In a task-scoped
repository fixture I changed only
`NativeDependencies/manifest.json -> libssh2-openssl.artifact.file_sha256["ios-arm64/Headers/libssh2.h"]`
from the accepted `aa542c...25bf` to `ba542c...25bf`, leaving the binding
manifest and all board evidence unchanged. The production validator returned
exit 0 with:

```json
{
  "failures": [],
  "manifestSha256": "39b3428d6cf778fa6b682bb0853a177d6b85f03b8062309f0d198dcdfd49fae6",
  "productionCompositionPermitted": true,
  "schemaVersion": 1
}
```

Evidence: `TASK-260720-1qhxqa_review-native-pin-mutant-rev5.log` and
`TASK-260720-1qhxqa_review-native-pin-mutant-report-rev5.json`.

This violates AC2's exact source/binary-pin binding and AC3's requirement that
permission remain true only for current, internally compatible inputs. It also
contradicts the human manifest's claim that checked-in native pins are verified.

Required rework:

1. Compare every selected SSH pin with a checked-in representation, including
   the patch SHA in `Dependencies/ReluxLibSSH2/PATCH_MANIFEST.json` and the
   accepted public-header SHA across all required artifact slices.
2. Fail closed on missing, malformed, duplicate, or inconsistent pin records,
   using a stable `REPOSITORY-SSH-PIN` row.
3. Add production-entry negative tests that narrowly change the patch lock and
   one public-header lock and require exit 1 with
   `productionCompositionPermitted=false`.

## Evidence accepted during this review

- Exact CR patch SHA-256 recomputed as
  `241f9dd32ffe1a494524ee905442a0fe6893baf0831996e6ef412f3301948777`;
  it matches the attached revision-5 patch.
- Repository manifest, owner outcome attachment, and sole-consumer precondition
  are byte-identical at
  `39b3428d6cf778fa6b682bb0853a177d6b85f03b8062309f0d198dcdfd49fae6`.
- All eight accepted M0/M1 outcome and reviewer-verdict resources were freshly
  materialized and independently matched their manifest SHA-256 values.
- `make m0-bindings-test`: exit 0, 17/17 tests passed.
- Unmodified `make m0-bindings-check TASK_BOARD_RESOURCES="$TASK_BOARD_DIR/.resources"`:
  exit 0, permission true.
- Python compile, JSON lint, and exact candidate `git diff --check`: exit 0.
- `task-board validate`: process exit 0 but printed two retained
  `PARENT_STATUS_MISMATCH` rows (`STORY-260715-1zzt0c` and owning
  `STORY-260715-1y04r0`); this is recorded as an anomaly, not a clean board.

The positive baseline and existing negative suite are credible for the covered
classes, including synchronized upstream-resource digest rebinding. They do not
cover F1, and the independently narrowed production mutant survives. Revision 5
therefore cannot be accepted.
