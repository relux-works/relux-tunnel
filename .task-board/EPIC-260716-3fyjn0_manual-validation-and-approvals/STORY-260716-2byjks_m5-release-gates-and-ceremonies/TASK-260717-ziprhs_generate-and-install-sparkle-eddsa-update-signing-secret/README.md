# TASK-260717-ziprhs: generate-and-install-sparkle-eddsa-update-signing-secret

## Description
MANUAL key ceremony. Generate the Sparkle EdDSA (ed25519) update-signing keypair, pin the PUBLIC key in the macOS app Info.plist (SUPublicEDKey), and install the PRIVATE key as the relux-tunnel GitHub Actions secret used by the appcast signing step. Store the private key in the same custody as the Developer ID / notarization credentials. AC: keypair generated with the updater vendor tool; public key committed to Info.plist; private key present as CI secret and never in git; a CI dry-run signs and verifies a test appcast entry. This is a credential action (secret handling) and stays human-owned.

## Scope
(define task scope)

## Acceptance Criteria
(define acceptance criteria)
