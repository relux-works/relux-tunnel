# TASK-260717-xempiv: integrate-sparkle-updater-into-macos-app

## Description
Embed and configure the chosen updater in ReluxProxyMac: link the framework, add SUFeedURL + SUPublicEDKey to Info.plist, wire SPUStandardUpdaterController (or equivalent) into app lifecycle, and ensure entitlements/hardened-runtime/sandbox settings remain valid and signable. AC: app builds signed with the updater embedded; updater initializes at launch; no notarization-breaking entitlements introduced; unit/smoke test confirms updater controller is constructed and feed URL resolves. Physical update install verification is tracked separately in the manual epic.

## Scope
(define task scope)

## Acceptance Criteria
(define acceptance criteria)
