# TASK-260715-29ws8l — final handoff evidence

Status: **accepted and done**.

## Delivered contract

The task-scoped production contract is `TASK-260715-29ws8l_profile-trust-credential-contract.md`, SHA-256 `8c81d2dc15904d6648f1333620370ac2c8c455e081fe6e98b4480a92c64bd5f2`.

It defines the complete macOS field, storage, trust, credential, generation, atomic-publication, Keychain query/ACL, lifetime, passphrase, cancellation, clearing, revocation, error, redaction, and ownership boundary. It consumes the accepted libssh2 M0 evidence without selecting an engine, preserves the macOS-only system-domain Keychain constraints, and carries no secret in `providerConfiguration`, diagnostics, or board evidence.

## M4 handoff

`TASK-260715-2hhh7x` owns the two exact approved-trust operations:

1. `approveFirstUseTrust(profileID:expectedConfigurationGeneration:challengeID:expectedTrustStateDigest:)`
2. `replaceApprovedTrust(profileID:expectedConfigurationGeneration:challengeID:expectedTrustStateDigest:)`

Both require the bounded probe/challenge compare-and-swap contract, explicit user action, WAL-backed publication, one-use challenge consumption, and no automatic reconnect. Human ratification remains decoupled under `TASK-260717-1dsqnj`.

## Focused traceability correction

- `TASK-260715-12zaq5` owns raw host-evidence decision ordering and first-use, approved, changed, unsupported, and revoked outcomes.
- `TASK-260715-13labb` owns stable bootstrap errors, retry classes, and diagnostic redaction.
- `TASK-260715-297imp` is only the composed integration-matrix consumer.

Live board task names and dependency links independently confirm these mappings. No architecture, schema, security semantic, dependency, task decomposition, planning artifact, or diagram changed.

## Reviewer verdict and gates

Accepted verdict: `TASK-260715-29ws8l_review-verdict-02.md`.

- Contract digest recomputation: exit 0; exact match.
- Required consumer scan: exit 0.
- Privacy sentinel: no matches; real `rg` exit 1, expected for a clean search.
- `git diff --check`: exit 0.
- `swift test --filter SSHTransportContractTests`: exit 0; 13 tests passed.
- Pre-verdict `task-board validate`: exit 0 but reported one transient parent-status mismatch while the hard-blocked task was in `reviewing`.
- Accepted status transition to `done`: exit 0; reviewer supplied no `commit_ack`.
- Post-transition `task-board validate`: exit 0; board valid with no issues.

The review modified no product source or contract bytes; only task-scoped verdict/results evidence and normal board lifecycle records were written.