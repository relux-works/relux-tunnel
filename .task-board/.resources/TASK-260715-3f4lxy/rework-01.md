# TASK-260715-3f4lxy focused rework 01

Implement only the reviewer-requested delta from `TASK-260715-3f4lxy_review-verdict.md`.

1. Make recursive prohibited-field detection reject deterministic normalized semantic variants of private-key, seed, passphrase, decrypted-key, key-byte, raw-host-key, password, and staging-credential fields. Add nested regression fixtures including `privateKeyMaterial`, `privateKeyData`, `passphraseBytes`, `passwordValue`, `seedBytes`, `decryptedPrivateKey`, and `stagingCredentialPayload`, with case and punctuation normalization coverage. Keep the policy bounded and avoid free-form heuristics.
2. Replace the superseded start expectation/configuration-reference seam with a versioned, bounded start request that carries configuration generation plus the exact canonical snapshot digest. A present start request must match the stored snapshot bytes exactly before first capture or fail with `profileGenerationMismatch`; nil start options may capture the validated stored snapshot. Add a regression proving same-generation field replacement is rejected on the first capture.
3. Preserve all already accepted constraints: providerConfiguration only, no App Group, no Keychain access in this loader, no secrets, no route/network work, 4096-byte bounds, immutable runtime capture, candidate-neutral core.
4. Run focused tests, full `swift test`, `swift build`, format lint, core-boundary validation, and `git diff --check`. Record the full-suite HEV result honestly; do not modify unrelated HEV behavior in this task.

Keep the rework delta focused. Update the task evidence and hand off to review; do not accept the task yourself.
