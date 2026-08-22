# TASK-260715-3cv3r4 independent review focus

Review the implementation independently against all five acceptance criteria and the task checklist.

Required adversarial checks:

- Prove the synthetic `MacOSSystemKeychainHandle` seam cannot reach `SecItemCopyMatching` or any other live Security API, cannot be constructed by product code accidentally through a public surface, and does not weaken exact query/reference isolation.
- Confirm the production change is the smallest coherent seam for deterministic fakes; reject force-fit, fallback, enumeration, silent live-Keychain access, or fixture identity leakage.
- Independently verify invalid profile snapshots stop before fake Keychain/network access and host-key policy runs before credential lookup and signing/authentication on every accepted/rejected path.
- Verify rotation, revocation, malformed evidence, unsupported algorithms, cancellation, cleanup, bounded repetitions, and prohibited-data/redaction coverage are behavioral rather than assertion-only placeholders.
- Re-run focused safe tests, coverage or an equivalent affected-scope measurement, format/boundary/diff checks. Do not run opt-in real-host or loopback SSH integration if it violates the binding no-network brief.
- Do not access the real Keychain, launch/install/sign a provider, create/start a VPN, or mutate routes, DNS, interfaces, or packet-filter state.

If accepted, attach a task-scoped review outcome and move the task to `done`. If material changes are required, attach exact evidence and route to `to-dev`.
