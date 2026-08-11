# TASK-260715-3f4lxy reviewer verdict — changes requested

## Verdict

Changes requested. Route to `to-dev`. The focused implementation is substantial and its 13 existing Swift Testing cases pass, but two fail-open contract gaps prevent acceptance. The repository-wide test gate is also currently red.

## Blocking findings

1. **Prohibited secret-equivalent field names are not exhaustively rejected.** `SSHProfileSnapshotCodec.decode` recursively collects keys, but `isProhibitedFieldName` only equality-matches a short fixed list (`SSHProfileSnapshot.swift:638-645`). A canonical unknown object containing `privateKeyMaterial` decodes successfully. Independent probe output: `PROHIBITED_EQUIVALENT_ACCEPTED`. This contradicts the accepted contract's prohibition of field names semantically equivalent to private key, seed, passphrase, decrypted key, key bytes, raw host key, password, or staging credential, and contradicts the task schema evidence claiming whole field families are rejected. Add a bounded normalized prefix/suffix/token policy (or another deterministic exhaustive rule) and regression fixtures for variants such as `privateKeyMaterial`, `privateKeyData`, `passphraseBytes`, `passwordValue`, `seedBytes`, `decryptedPrivateKey`, and `stagingCredentialPayload` at multiple nesting positions.

2. **The first runtime capture cannot reject a same-generation replacement.** `SSHProfileSnapshotExpectation` carries only profile ID and generation (`SSHProfileSnapshot.swift:765-772`), and the initial capture compares only those values (`SSHProfileSnapshot.swift:798-803`). A fresh loader therefore accepted a snapshot whose `account` was changed while profile ID and generation stayed the same. Independent probe output: `FIRST_CAPTURE_REPLACEMENT_ACCEPTED account=changed-account`. The accepted digest `8c81d2dc15904d6648f1333620370ac2c8c455e081fe6e98b4480a92c64bd5f2`, §4, requires a host start request with configuration generation plus snapshot digest and exact stored-snapshot matching, returning `profileGenerationMismatch` on mismatch. The existing `RuntimeStartRequest` still carries the superseded opaque configuration reference (`RuntimeMessageModels.swift:194-228`). Update the start expectation/request seam to bind a canonical snapshot digest and add a first-capture replacement regression test. Nil start options may still capture the validated stored snapshot as the contract allows.

## Independent gates

- Accepted contract SHA-256 verification — exit 0; exact digest matched.
- `swift test --filter SSHProfileSnapshotLoaderTests` — exit 0; 13/13 passed.
- Independent temporary consumer probe — exit 0; reproduced both fail-open cases above without modifying repository source.
- `swift test` attempt 1 — exit 1; 391 tests, one HEV UDP timing assertion failed.
- `swift test --filter HEVUDPDatagramAdapterTests` — exit 0; 12/12 passed in isolation.
- `swift test` attempt 2 — exit 1; 391 tests, five HEV UDP issues across two tests. Loader tests remained green. The full-suite gate is therefore recorded as failing, not waived.
- `swift build` — exit 0; only the existing linker alignment warning.
- `swift format lint --recursive Sources Tests Package.swift` — exit 0.
- `make check-core-boundaries` — exit 0.
- `git diff --check -- Sources Tests LOGBOOK.md` — exit 0.
- `task-board validate` — process exit 0 but reported `PARENT_STATUS_MISMATCH` for `STORY-260715-2wjwuf` versus the child aggregate; board files were not edited directly.

## Re-review requirements

- Add focused secret-equivalent key fixtures demonstrating deterministic rejection across nesting and punctuation/case normalization.
- Bind a present start request to the exact stored canonical snapshot digest and generation; reject a same-generation replacement on the first capture.
- Re-run focused loader tests, the full suite, build, format lint, core-boundary validation, and diff check with real exit codes.
