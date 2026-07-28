# Mandatory independent-review focus

Do not accept the producer plan merely because board validation is green. Verify these specific risks:

1. Ceremony C1 claims one short human session but places agent build, independent review, and signed disposable-probe work between portal authorization and the system-VPN approval. Decide whether this must be split into an up-front permission ceremony plus a later brief approval prompt.
2. The owner-supplied notarization API private key currently exists as a mode-0600 `.p8` file. The project invariant says secrets are Keychain-only. Require a safe import/migration/custody resolution and do not expose the path, key ID, issuer ID, or bytes.
3. Sparkle public-key insertion and CI signing verification may depend on a generated macOS target/workflow that does not exist at Ceremony C1. Verify dependency ordering; keep local key generation possible without claiming downstream integration complete.
4. The plan claims 202 autonomous tasks with no human input, but lists `intsjz`, `35nc5m`, `2gwfaw`, and `3gkwn0` as human product decisions and includes physical-evidence tasks. Require either explicit up-front defaults/decisions or honest hold points.
5. Audit every removed dependency edge: A0/iPhone/Linux may be deferred, but host-key-before-auth, Keychain-only secrets, fail-closed DNS, bounded memory, macOS provisioning/P0, Developer ID/notary, physical routing/DNS-leak validation, and release signing must remain enforced.
6. Verify `TASK-260715-1ozsb6` is not made runnable before the contract-rescope task `TASK-260728-yx2fca` is accepted, and Tier-2 M3 semantics cannot be silently fabricated or forgotten.