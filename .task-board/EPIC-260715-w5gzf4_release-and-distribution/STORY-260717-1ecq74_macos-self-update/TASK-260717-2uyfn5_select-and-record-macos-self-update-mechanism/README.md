# TASK-260717-2uyfn5: select-and-record-macos-self-update-mechanism

## Description
Decide and record the macOS self-update design as an ADR. Default: Sparkle 2.x, EdDSA (ed25519) appcast signatures, delta updates optional, appcast + release assets served from the GitHub release channel used by the notarized DMG. Evaluate against: hardened-runtime/sandbox compatibility, Developer ID + notarization preservation, extension/system-extension re-approval behavior on update, and dependency license (Sparkle is MIT). AC: ADR records chosen framework+version, signing scheme, appcast hosting, update cadence/channels (stable vs pre-release), and the explicit rule that every update payload is an already-notarized Developer ID build. Autonomous: desk decision from spec + upstream docs; no human sign-off needed to reach to-review.

## Scope
(define task scope)

## Acceptance Criteria
(define acceptance criteria)
