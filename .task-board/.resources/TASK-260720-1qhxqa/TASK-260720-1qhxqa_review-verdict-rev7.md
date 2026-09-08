# TASK-260720-1qhxqa review verdict — CR revision 7

Verdict: CHANGES REQUESTED. Route the task to `to-dev`; do not call
`accept_cr` for revision 7.

## Exact scope identity

- Change Request: `CR-TASK-260720-1qhxqa-7`, revision 7.
- Base OID: `b3422b05226253a17676b9b84c764071fe3dbe74`.
- Candidate tree OID: `e0300db1db3887aed54281d8afddb1de332b2cb1`.
- The independently generated seven-path patch SHA-256 is
  `c08e390dd34daaaade9cf8bf10ffd6d12dc2a82121e37bac82fcc30d9d44bb27`,
  matching the named CR patch resource. Every working-tree candidate blob
  matched the candidate tree OID.

## Blocking findings

### 1. High — ambiguous manifest JSON fails open at the production validator

`scripts/validate-m0-production-bindings.py` parses the binding manifest with
plain `json.loads`, although its checked-in pin-document helper explicitly
rejects duplicate JSON keys. JSON objects with duplicate names are ambiguous:
different consumers can select the first or last value.

The reviewer mutant changed the manifest bytes by inserting a first root field
`"schemaVersion": 999` while retaining the later accepted
`"schemaVersion": 1`. The changed manifest SHA-256 is
`46904b5790f20d94ecf2f9ef77b7bac89b67c77e140f883abe049a29893c6cec`.
The exact production validator CLI returned exit 0, no failures, and
`productionCompositionPermitted=true`. This admits an ambiguous/unknown schema
version and violates the task's fail-closed rule plus AC 3 and AC 4. The Make
production gate invokes this same validator from `m0-bindings-check`.

Required rework: parse the manifest (and preferably the board-state JSON at the
same trust boundary) with duplicate-key rejection, emit a stable refusal row,
and add a durable production-entry negative test that preserves duplicate raw
keys and proves exit 1 with `productionCompositionPermitted=false`.

Evidence:

- `TASK-260720-1qhxqa_review-duplicate-schema-mutant-rev7.json`
- `TASK-260720-1qhxqa_review-duplicate-schema-mutant-report-rev7.json`
- `TASK-260720-1qhxqa_review-duplicate-schema-mutant-rev7.log`

### 2. Medium — accepted SSH integrity bindings are not fully normalized

The exact accepted SSH ADR's “Exact selected dependency pins and packaging”
table binds the libssh2 `COPYING` SHA-256, OpenSSL license SHA-256, OpenSSL
acknowledgements SHA-256, and retained ReluxNIOSSH fork-patch SHA-256. The
machine manifest records general notice obligations and some dependency pins,
but omits those exact integrity values. Therefore its canonical normalized
digest cannot detect their removal or mutation, despite AC 2 requiring every
license/maintenance and fork-disposition binding from the accepted outcomes.

Required rework: normalize the exact accepted integrity values, update the
independent canonical trust root, and add negative coverage proving mutation or
removal is refused.

Authoritative source: `TASK-260715-1gjxer_ssh-engine-selection-adr.md`, lines
63–68. Current machine projection:
`Configuration/TASK-260720-1qhxqa_m0-production-bindings-v1.json`, SSH
`sourceOrBinaryPins` and `licenseAndMaintenanceObligations`.

## Independent validation

- All eight exact upstream outcome/verdict SHA-256 values matched the manifest.
- Repository, owner attachment, and sole-consumer attachment were byte-identical
  at SHA-256
  `39b3428d6cf778fa6b682bb0853a177d6b85f03b8062309f0d198dcdfd49fae6`.
- `TASK-260715-3ejhyy` declares this manifest as its sole M0 precondition.
- `make m0-bindings-test`: exit 0, 22/22 tests passed.
- `make m0-bindings-check`: exit 0 for the unchanged baseline, permit true.
- `make check-native-dependencies`: exit 0.
- Python compile and exact candidate `git diff --check`: exit 0.
- `task-board validate`: process exit 0, but retained two
  `PARENT_STATUS_MISMATCH` rows (`STORY-260715-1zzt0c` and the owning Story);
  this is not represented as a clean board validation.

The positive baseline evidence is sound but cannot compensate for the
production gate admitting the narrowing mutant. No repository files were
changed by the reviewer.
