# STORY-260717-1ecq74: macos-self-update

## Description
Signed, notarization-compatible in-app self-update for the macOS app so security fixes reach users without a manual re-download. Sparkle 2.x with EdDSA-signed appcast, delivered from the same GitHub release channel as the notarized DMG. iOS is intentionally out of scope (App Store owns updates). In scope: updater framework integration, EdDSA appcast signing in CI, update settings UI and background scheduling, integrity/rollback tests, and channel/key runbook. Update payloads are the already-notarized Developer ID app, so Gatekeeper and hardened-runtime guarantees are preserved end to end.

## Scope
(define story scope)

## Acceptance Criteria
(define acceptance criteria)
