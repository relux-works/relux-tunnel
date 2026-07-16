# Document relay update, rollback, and supply-chain incident operations

## Description
Create an operator runbook for updating relay inputs, rotating toolchains, regenerating evidence, promoting compatible assets, rolling back safely, revoking compromised material, and responding to vulnerabilities or provenance failures.

## Scope
In scope: change intake, compatibility and protocol gates, pin updates, license review, rebuild and reproducibility, manifest and SBOM diff review, scan exceptions, staging promotion, Apple-bundle consumers, rollback to prior known-good assets, vulnerable or compromised release withdrawal, attestation trust rotation, retention, communications, owners, and rehearsal. Out of scope: runtime remote upgrade implementation, production traffic operations, Apple store rollback details, and vague advice without commands or decision criteria.

## Acceptance Criteria
1. The runbook gives ordered commands or workflow references, required roles, inputs, evidence, approvals, abort criteria, and expected outputs for routine dependency and toolchain updates. 2. Protocol-compatible and protocol-breaking changes have distinct migration, application-bundle, and rollback requirements. 3. A rollback identifies the exact prior manifest and asset digests, verifies compatibility, rebuilds no bytes, and traces every consuming macOS or iOS candidate. 4. Vulnerability, compromised dependency, builder, attestation identity, secret, or hash mismatch scenarios define containment, credential or trust revocation, artifact withdrawal, notification, and reissue. 5. A tabletop or safe rehearsal records timing, commands, gaps, ownership, and corrections for one update and one incident or rollback scenario.
