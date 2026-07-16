# TASK-260717-1mt4e7: implement-signed-appcast-and-release-asset-generation

## Description
Add a reproducible pipeline step that, on tagged release, produces the appcast.xml with EdDSA signatures for each update asset and publishes it alongside the notarized DMG/zip to the stable release channel. Signing uses the Sparkle EdDSA private key provided via CI secret (public key pinned in Info.plist). AC: given a built+notarized artifact, the step emits a valid signed appcast entry (version, min-system-version, ed signature, url, length) and validates it with the updater's verification tool; missing/invalid key fails closed. Key ceremony (generating and installing the secret) is tracked in the manual epic.

## Scope
(define task scope)

## Acceptance Criteria
(define acceptance criteria)
