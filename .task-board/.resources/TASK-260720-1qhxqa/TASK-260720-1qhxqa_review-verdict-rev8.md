# TASK-260720-1qhxqa review verdict — CR revision 8

Verdict: CHANGES REQUESTED. Route to `to-dev`.

## Blocking finding

The production validator fails open when the checked-in macOS HEV binary changes.
`verify_repository` reads the `hev-lwip` revision and submodule revisions from
`NativeDependencies/manifest.json`, but it does not compare the manifest's
`artifact.file_sha256` locks with the actual files under
`NativeDependencies/Artifacts/HevSocks5Tunnel.xcframework`.

An isolated repository fixture retained the exact accepted manifest, board state,
resource bytes, project graph, native manifest, and SSH artifacts. The reviewer
appended one byte to
`macos-arm64_x86_64/libhev-socks5-tunnel.a`, changing its size from 1,351,136 to
1,351,137 bytes while leaving the accepted artifact lock unchanged. The exact
production CLI returned exit 0, no failures, and
`productionCompositionPermitted=true`.

This defeats the required exact accepted source/binary pin and lets changed
production HEV bytes retain permission. It violates AC3 and AC4 and the manifest's
own `artifactLock` binding. The existing negative suite covers actual selected
libssh2 patch/header bytes but has no equivalent HEV artifact-byte mutant.

Required rework:

1. Bind the required HEV XCFramework artifact lock/file set to the accepted
   manifest without reselecting or tuning HEV.
2. At the production validator call site, verify every required HEV artifact file
   path and SHA-256 (including the macOS production archive) against the checked-in
   lock; reject missing, extra/ambiguous where applicable, malformed, duplicate,
   or byte-drifted records at a stable failure row.
3. Add a durable production-entry negative regression that mutates an actual HEV
   artifact byte while leaving locks unchanged and requires exit 1 with
   `productionCompositionPermitted=false`. Also cover lock drift independently.

Evidence: `TASK-260720-1qhxqa_review-hev-byte-mutant-rev8.log` and
`TASK-260720-1qhxqa_review-hev-byte-mutant-report-rev8.json`.

## Passing independent gates

- Exact CR patch SHA-256 matched `55c53694673028b3450ac21cfc1a5324f75781b62fa23e5dff3a9d311b1fb4ae`.
- All seven workspace blobs matched candidate tree
  `6beb6784fd59d90c896623dfe943f173e11153ed`; exact diff lint passed.
- All eight accepted M0/runtime outcome and verdict resource SHA-256 values matched.
- `make m0-bindings-test`: exit 0, 27/27 tests.
- `make m0-bindings-check TASK_BOARD_RESOURCES="$TASK_BOARD_DIR/.resources"`:
  exit 0 on the unchanged baseline, manifest SHA-256
  `0deddb2a2692cecb17a0650741f74577c945600de97c9a41970b035b452f0361`.
- `make check-native-dependencies`: exit 0 on the unchanged baseline.
- Python compile and exact candidate `git diff --check`: exit 0.
- The authoritative `TASK-260715-3ejhyy` sole-consumer precondition was
  rematerialized and matched the candidate manifest SHA-256 `0deddb2a...`.

The unchanged baseline passing does not override the negative mutant. No
repository source was modified by the reviewer; all mutant files are isolated
under `.temp/TASK-260720-1qhxqa-review/`.
