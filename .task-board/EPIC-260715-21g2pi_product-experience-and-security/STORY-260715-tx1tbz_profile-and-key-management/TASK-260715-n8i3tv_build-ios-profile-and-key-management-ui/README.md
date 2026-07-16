# Build the iOS profile and key management UI

## Description
Build native iOS profile list and editor surfaces backed by the shared model, with key selection, explicit import/generation entry points, destructive confirmations, privacy-safe errors, and accessibility across supported phone layouts.

## Scope
In scope: empty/list/editor states, display name, host/address, port, account, key selector, import and generation actions, optional passphrase policy presentation, save/cancel/delete, selected and active profile indicators, navigation, file importer/share sheet adapters, Dynamic Type, VoiceOver, focus, reduced motion, shared accessibility identifiers, and screenshots. Out of scope: host-trust prompt, connection dashboard, diagnostics, raw key display, custom file browser, and iPad-specific layouts unless included by deployment policy.

## Acceptance Criteria
1. A user can create, edit, select, and delete profiles and import or generate a key through labeled controls whose enabled state and errors match the shared model. 2. Destructive key/profile actions and any contract-permitted private export require explicit confirmation and never display or copy secret material accidentally. 3. Loading, empty, conflict, cancellation, repository, Keychain, importer, generator, and active-session errors have actionable accessible recovery. 4. The surface supports the approved Dynamic Type range, VoiceOver order/labels/values/hints, keyboard focus where applicable, contrast, reduced motion, and stable shared identifiers. 5. Snapshot and Page Object fixtures render all required states on the smallest and representative current phone sizes without clipping or black screens.
