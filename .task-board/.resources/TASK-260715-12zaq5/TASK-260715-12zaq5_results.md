# TASK-260715-12zaq5 reviewer verdict

Verdict: accepted.

## Acceptance evidence

- The selected libssh2 adapter obtains raw wire host-key evidence after key exchange, evaluates the injected policy before credential lookup, and can construct authentication acceptance only from an approved decision. Rejected and untrusted decisions tear down the connection before authentication or destination-channel creation.
- `SSHApprovedHostIdentityPolicy` performs exact reviewed-algorithm matching, local SHA-256 fingerprint calculation, constant-time digest comparison, canonical host and port binding, wire-key shape validation, revoked-before-approved evaluation, and privacy-safe typed results.
- First use returns canonical host, port, reviewed algorithm, canonical SHA-256 fingerprint, and observation time without producing authentication acceptance. Changed, revoked, unsupported, malformed, and host-mismatched inputs are terminal until configuration changes.
- `SSHProfileSnapshotV1` decoding and runtime policy construction both enforce at most one active approved identity. Rotation tests use complete sequential snapshot generations with canonically ordered revoked history and one current approval. `TASK-260715-29ws8l` remains authoritative.
- Production macOS policy construction exposes only the immutable snapshot-backed policy bound to selected libssh2 capabilities; no accept-all, TOFU auto-accept, or first-use acceptance path exists there.
- Raw host-key bytes remain inside policy input. Accepted session and credential-request values carry only verified identity and non-secret audit metadata; printable evidence, inputs, decisions, acceptances, credential requests, and sessions redact sensitive values.

## Independent reviewer gates

- `swift test --filter SSHProfileSnapshotLoaderTests`: exit 0; 13 tests passed.
- `swift test --filter ApprovedHostIdentityPolicyTests`: exit 0; 9 tests passed.
- `swift test --filter mandatoryHostPolicyOrdering`: exit 0; 1 live loopback test passed, with zero credential-provider calls, authentication attempts, direct channels, and exec channels for every rejected or untrusted host class.
- `swift format lint --recursive Sources Tests Package.swift`: exit 0.
- `git diff --check`: exit 0.
- `make validate-core`: exit 0; core boundaries and native/libssh2 verification passed, all 413 Swift tests passed, and the final build passed.
- The previously reported unrelated HEV hang did not reproduce; the real-HEV 100-cycle regression completed in the reviewer run. No HEV code was modified.

Reviewer conclusion: implementation matches the corrected acceptance criteria and accepted one-active-identity contract, fits the core/selected-adapter/macOS-composition architecture, and is accepted for the commit-owning mover.
