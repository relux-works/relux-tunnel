# Active macOS host-identity policy scope

Binding inputs:

- `TASK-260715-29ws8l_profile-trust-credential-contract.md` is the accepted authority for canonical host binding, approved/revoked identity records, trust challenge schema, ordering, and privacy.
- `TASK-260720-100wu6` provides the candidate-neutral pre-auth host-verification seam; libssh2 is the selected primary engine.
- `TASK-260715-3f4lxy` now provides the complete immutable validated `SSHProfileSnapshotV1` and exact host policy records.

Implementation constraints:

1. Host identity verification must complete before any credential lookup or user-authentication attempt. Production composition has no accept-all, bypass, TOFU auto-accept, test-policy fallback, or retry-on-security-failure path.
2. Consume raw wire host-key evidence from the SSH adapter, normalize only reviewed algorithm labels, compute the SHA-256 fingerprint locally, and compare approved records without leaking raw key bytes. Preserve the accepted canonical host from the immutable snapshot.
3. First use returns the exact bounded non-secret `ProbeHostIdentityV1`/trust-required evidence for a containing-app action and does not authenticate. Approved match accepts; changed, revoked, unsupported, malformed, and host-mismatched identities fail closed and are terminal until profile/trust state changes.
4. Preserve the accepted profile invariant of at most one active approved identity. Rotation is deterministic and sequential: historical and revoked records remain canonically ordered for audit, while a replacement becomes active only through a separately published complete snapshot generation. Return non-secret state-transition/audit metadata only; this task does not write the containing-app profile repository.
5. Use Swift Testing for same/different/malformed keys, invalid label with same bytes, first use, sequential rotation history with one active approval, revocation, canonical-host mismatch, cancellation/order, and redaction. Add a composition-order test proving credential provider invocation count remains zero for every rejected/untrusted host case.
6. Do not invent host-certificate CA semantics, DNSSEC, UI copy, retry policy beyond typed classification, or physical tuning.

Keep all logs and board evidence free of raw host-key bytes, addresses beyond fixed documentation fixtures, credential references, or secrets.
