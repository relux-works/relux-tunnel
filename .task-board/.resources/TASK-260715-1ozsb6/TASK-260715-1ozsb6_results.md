# TASK-260715-1ozsb6 developer handoff — review-round-11 rework

Status: ready for review.

## Outcome

- Closed the round-11 Ed25519 evidence gap with a live loopback OpenSSH test using an in-memory `Curve25519.Signing.PrivateKey` behind `SSHPublicKeyCredential`. The test records a real opaque external-signer callback invocation, proves host policy precedes credential lookup, uses only `keychain.fixture.ed25519` as the secret reference, exercises exec, and restores the complete owned-resource snapshot to zero.
- Retained the existing live P-256 deployed-fallback coverage.
- Closed the automatic client-rekey evidence gaps with deterministic protected-byte and injected-monotonic-time threshold tests. Each test reaches the production libssh2 KEX path under an open channel, asserts typed trigger/success events and the matching `clientByteRekeys` or `clientTimeRekeys` counter, proves post-KEX traffic, and restores sessions, channels, sockets, tasks, custom allocations, and buffers to zero after cancel/close.
- Recorded the test-design finding that a full-duplex echo can legitimately cross a per-direction protected-byte threshold in both directions. The final byte-threshold fixture uses bounded one-directional exec/stdin traffic so one exact trigger is reproducible without masking a valid second KEX.
- The pinned static libssh2/OpenSSL adapter remains isolated behind the candidate-neutral Core boundary and registered only in the approved macOS provider and harness graphs.
- Consumer receive credit, RFC channel-open reasons, exact exec-exit metadata, and deep rekey/keepalive observability remain explicit `unsupported` or `notReported` states owned by `TASK-260728-3cveay`; no deferred value is fabricated.

## Validation

- `swift test --filter ed25519ExternalSignerAuthentication`: exit 0, 1 live adapter test.
- `swift test --filter automaticElapsedTimeRekey`: exit 0, 1 live adapter test.
- Initial full-duplex byte-threshold test: exit 1 because the fixture legitimately crossed sent and received per-direction thresholds; no adapter row was marked green from that run. The bounded one-directional replacement then passed five consecutive focused runs, all exit 0.
- First combined `swift test --filter LibSSH2` before the deterministic byte-fixture correction: exit 1, with the same second-threshold/state-transition expectation. After correction, three consecutive runs passed, each exit 0 with 44 tests in 3 suites.
- `make validate-core`: exit 0, 378 tests / 31 suites plus candidate boundary verification and `swift build`.
- `make validate-libssh2`: exit 0; pinned static extension-safe XCFramework, public fork API, notices, client/server KEX, and global-request evidence passed.
- `make test-libssh2-source-gates`: exit 0; libssh2/OpenSSL tampering rejected before extraction or patching.
- `make native-apple-matrix`: exit 0; arm64/x86_64 macOS provider and harness release targets compile/link the pinned extension-safe graph.
- `swift-format lint --recursive --strict Package.swift Sources Tests`: exit 0.
- `git diff --check`: exit 0.
- `task-board validate`: exit 0 while visibly reporting the pre-existing `STORY-260715-lkshfz` aggregate mismatch (`to-dev` versus child `development`).
- Preconditions reproduce declared SHA-256 values: contract `207b5834794202a5a3c051b248b80ddeaab0888399a9e39dd4b65274c57bddf7`; inputs `fec044ef6b854a21318027399eaaa59e6862a653be8106d2c644141cbbed488c`.

## Review focus

- Verify the Ed25519 fixture signs through the adapter callback rather than file-based libssh2 authentication and that host-policy ordering plus zero ownership are asserted.
- Verify `automaticProtectedByteRekey` and `automaticElapsedTimeRekey` assert production KEX events/counters, traffic survival, and zero ownership.
- Confirm the four M3-deferred semantics remain explicit and traceable to `TASK-260728-3cveay`.
