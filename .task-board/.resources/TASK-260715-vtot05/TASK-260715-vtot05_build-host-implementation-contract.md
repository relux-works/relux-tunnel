# Relay provenance implementation contract

Implement `TASK-260715-vtot05` entirely as build-time, repository-local supply-chain work.

## Accepted inputs

- `TASK-260715-1ue4oy` is accepted: use its generated relay asset manifest, schema, Swift lookup, and drift gates as the manifest integration point.
- `TASK-260715-24icoz` is accepted: use its portable four-platform relay asset archive and recorded hashes as immutable artifact evidence.
- `TASK-260715-27uz4n` is accepted: use its pinned relay source/build inputs and reproducibility evidence.
- Preserve the accepted protocol-v1 developer contract already attached to this task.

## Required implementation boundaries

- Trace every byte-affecting relay source/build dependency to immutable revision or content hash, license/SPDX identity, notice obligation, and provenance record.
- Generate machine-readable inventory and product notice input; fail closed on missing, mutable, mismatched, or unapproved metadata.
- Link provenance to the existing generated asset manifest without credentials, tokens, local usernames, workstation paths, temporary paths, or mutable URLs.
- Keep M2 integrity/provenance separate from M5 signing, notarization, attestation, and distribution approval.
- Add one clean audit command covering locks, hashes, notices, inventory consistency, manifest linkage, and the invariant that application runtime never downloads executable code.
- Prefer deterministic generation plus focused negative tests. Do not weaken existing manifest/archive verification.

## Build-host safety

This Mac is build-only. Do not sign, install, launch, or activate the app or packet-tunnel provider. Do not create/save/remove/enable VPN preferences, call `startVPNTunnel`, alter routes/interfaces/pf/DNS, or run physical/system-VPN validation. Unsigned compilation, repository tests, rootless relay processes, local fixture servers, and the SPM harness are allowed only when they do not change host networking.

Do not read, copy, print, attach, or record paths to notarization credentials, `.p8` files, Keychain secrets, or private signing material. Do not add App Groups or Keychain Sharing.

Finish with scoped tests and attach an evidence-backed outcome. Stop with a precise blocker packet rather than adding a workaround if any accepted invariant cannot be met.
