# TASK-260715-1ozsb6 reviewer result — round 11

Verdict: CHANGES REQUESTED. Route to `to-dev`.

The round-10 order-sensitive timeout ownership defect is closed. Three consecutive executions of the exact `swift test --filter LibSSH2` gate passed 41 tests in 3 suites, including `nonCooperativeUploadSourceTimeout`; cooperative timeout children retire before the bounded assertion, the one cancellation-ignoring upload source remains visible, and explicit release restores the complete ownership snapshot to zero. Packaging, source integrity, macOS linkage, lifecycle, explicit M3-deferred states, lint, and builds are green.

## Blocking M0 conformance-evidence gaps

1. The required Ed25519 opaque-external-signer path has no live adapter test. The revised M0 contract requires noninteractive Ed25519 plus an approved deployed fallback through opaque external signing. `LibSSH2AdapterIntegrationTests.swift` defines and uses only `P256FixtureCredential` for successful live adapter authentication (lines 788-806 and 1126-1148). The pinned C rekey probe authenticates an Ed25519 key from files with `libssh2_userauth_publickey_fromfile`, so it does not exercise `SSHPublicKeyCredential.sign`, the adapter callback, or the Keychain-only boundary. The scoped search for `Curve25519.Signing`, an Ed25519 fixture, an `ssh-ed25519` integration credential, or an Ed25519 credential reference exited 1.

2. The mandatory automatic client-rekey paths have no positive adapter conformance test. Production code contains the time trigger at `LibSSH2Transport.swift:1173-1179` and the protected-byte trigger at `LibSSH2Transport.swift:2010-2024`, but integration coverage invokes only `.manual` and `.test` (`LibSSH2AdapterIntegrationTests.swift:102-104,961`). Its shared live configuration disables practical automatic triggers with `protectedByteThresholdPerDirection: .max` and `elapsedTimeThreshold: .seconds(3_600)` (lines 1731-1734). The scoped test search for `.byteThreshold`, `.timeThreshold`, `clientByteRekeys`, or `clientTimeRekeys` exited 1. Server `RekeyLimit 32K` evidence proves inbound server KEX, not either client automatic trigger.

These are M0-viability-mandatory rows, not any of the four M3-deferred semantics. AC 3 and the relevant-tests/implementation-matches-AC gates therefore remain red until positive evidence exists or a real failure is explicitly recorded red.

## Required rework

- Add a live loopback adapter test using an in-memory Ed25519 `SSHPublicKeyCredential` and the external signing callback. Assert successful pre-auth host policy ordering, authentication, and zero owned-resource baseline after close. Retain the P-256 fallback coverage.
- Add deterministic adapter tests for byte-threshold and time-threshold client rekey under active channel traffic. Assert each trigger reaches the production KEX path, emits/reconciles its typed trigger and success evidence, increments `clientByteRekeys` or `clientTimeRekeys`, preserves traffic, and returns tasks/channels/socket/session/allocations/buffers to baseline after cancellation/close.
- If either new test exposes an adapter defect, fix it and rerun the full submitted gate set. Do not replace the mandatory row with capability declarations or the M3 unsupported reports.

## Independent validation

- `swift test --filter LibSSH2`: exit 0 three consecutive times; 41 tests / 3 suites each.
- `make validate-core`: exit 0; 375 tests / 31 suites plus boundary verification and `swift build`.
- `make validate-libssh2`: exit 0; pinned static extension-safe XCFramework, fork/public API, client/server KEX, global-request, and notice checks passed.
- `make test-libssh2-source-gates`: exit 0; libssh2/OpenSSL tampering rejected before extraction or patching.
- `make native-apple-matrix`: exit 0; arm64/x86_64 macOS provider and harness release targets compile/link the approved static graph; iOS native-only rows remain unchanged.
- `swift-format lint --recursive --strict Package.swift Sources Tests`: exit 0.
- `git diff --check`: exit 0.
- `task-board validate`: exit 0 while reporting the visible `STORY-260715-lkshfz` parent aggregate mismatch (`to-dev` versus child `reviewing`).
- Preconditions reproduce declared byte counts and SHA-256 digests: contract `207b5834794202a5a3c051b248b80ddeaab0888399a9e39dd4b65274c57bddf7`; inputs `fec044ef6b854a21318027399eaaa59e6862a653be8106d2c644141cbbed488c`.

The four M3-deferred semantics remain explicit `unsupported`/`notReported` states traceable to `TASK-260728-3cveay`; they are not rejection reasons.
