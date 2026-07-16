# Build the macOS profile and key management UI

## Description
Build native macOS profile list and editor surfaces backed by the shared model, including keyboard-first operation, system file/save panels, key actions, destructive confirmations, and clear active/selected profile state.

## Scope
In scope: window/settings or menu-app navigation approved by the target architecture, list/editor split, all profile fields, key selector, import, generation, optional export, save/cancel/delete, active and selected indicators, macOS open/save/share adapters, commands, focus, tab order, VoiceOver, text scaling, shared identifiers, and screenshots. Out of scope: legacy SOCKS settings, host-trust prompt, connection dashboard, raw key display, custom file browser, and release packaging.

## Acceptance Criteria
1. All profile and key actions are reachable by pointer and keyboard with deterministic focus, standard shortcuts where appropriate, and no hidden menu-bar-only operation. 2. Validation, dirty-state, selected/active conflicts, destructive confirmations, and repository/Keychain errors mirror the shared model and remain readable at supported text scaling. 3. File import and any allowed export use system panels, retain access only for the operation lifetime, and clean temporary private data on cancel or failure. 4. VoiceOver labels, roles, values, help, grouping, contrast, reduced motion, and shared identifiers pass the defined accessibility checks. 5. Snapshot and XCUITest fixtures cover empty, list, editor, error, import/generate, confirmation, and relaunch states without layout truncation.
