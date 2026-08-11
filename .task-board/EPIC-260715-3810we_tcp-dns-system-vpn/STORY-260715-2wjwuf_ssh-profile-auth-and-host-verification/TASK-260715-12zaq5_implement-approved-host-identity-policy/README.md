# Implement mandatory approved host-identity policy

## Description
Implement the candidate-neutral host-key policy invoked by the selected SSH adapter before user authentication acceptance. Compare raw server key evidence with the approved profile identities, return explicit trust-required evidence on first use, reject change or revocation, and preserve privacy-safe audit metadata.

## Scope
In scope: SSH key algorithm normalization, SHA-256 fingerprint calculation and constant-time comparison where appropriate, multiple approved keys for rotation, provenance and first or last seen updates through a non-secret result, first-use evidence, changed key, unsupported algorithm, revoked entry, canonical host binding, and retry classification. Out of scope: presenting or accepting trust in the provider, certificate-authority host cert design unless already approved by M0, DNSSEC, TOFU auto-accept, multi-lane enforcement, and UI copy.

## Acceptance Criteria
1. Host-key policy runs before any credential lookup or user-authentication request and no bypass or accept-all mode exists in production composition. 2. First use returns full algorithm and SHA-256 fingerprint evidence plus canonical host for an explicit containing-app trust action and does not authenticate. 3. An approved fingerprint connects, while a changed, revoked, unsupported, malformed, or host-mismatched key fails without automatic retry or opening destination channels. 4. Rotation is deterministic and sequential under the accepted profile contract: historical/revoked records remain ordered for audit while at most one active approved identity exists; the policy records only non-secret provenance and timestamps. 5. Swift Testing includes same key, different key, invalid algorithm label with same bytes, malformed key, sequential rotation history, revocation, canonical-host mismatch, pre-auth composition ordering, and logging redaction.
