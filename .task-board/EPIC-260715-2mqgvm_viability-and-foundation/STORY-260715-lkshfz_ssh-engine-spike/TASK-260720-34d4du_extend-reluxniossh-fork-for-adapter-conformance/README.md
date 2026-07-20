# TASK-260720-34d4du: extend-reluxniossh-fork-for-adapter-conformance

## Description
Extend the ReluxNIOSSH minimal fork (TASK-260715-nzdzv3) with the three public API surfaces the candidate-neutral contract (TASK-260720-100wu6) requires for the NIOSSH adapter (TASK-260715-1af33i), discovered during adapter integration (see TASK-260715-1af33i_fork-api-blocker.md). Keep concrete NIOSSH types inside the fork/adapter boundary; PRESERVE the security-preserving async-external-signer contract (private keys stay in Keychain, never exported). Extend the existing 16-file allowlist delta minimally; the growing delta is recorded evidence for the eventual engine selection (TASK-260715-1gjxer).

## Scope
(define task scope)

## Acceptance Criteria
1. Public external public-key signer auth offer: an async signature path accepting wire-format public key + algorithm and calling back for the signature over NIOSSH's constructed payload, WITHOUT requiring or exporting a concrete NIOSSHPrivateKey; a deterministic fork test proves auth succeeds via an external async signer. 2. Public reply-observing keepalive/global-request: send keepalive@openssh.com (or a generic global request) with want-reply, bounded payload, preserving NIOSSH packet ordering/encryption/MAC and request-response ordering, exposing reply completion for RTT; a fork test proves the request->reply round-trip. 3. Caller-configurable KEX and host-key allowlists PLUS a public immutable negotiated-algorithm snapshot/event reporting exact KEX, host key, cipher, MAC; a fork test proves the allowlist constrains negotiation and the snapshot reports actual negotiated values (not configured lists). 4. Added delta stays minimal + allowlisted, documented in PATCH_MANIFEST/delta doc; upstream crypto/algorithms unchanged; Apache-2.0 attribution preserved; the 323 upstream tests still pass. 5. swift build, the new fork tests, and make validate-core (no NIOSSH/SwiftNIO leak into ReluxTunnelCore) pass.
