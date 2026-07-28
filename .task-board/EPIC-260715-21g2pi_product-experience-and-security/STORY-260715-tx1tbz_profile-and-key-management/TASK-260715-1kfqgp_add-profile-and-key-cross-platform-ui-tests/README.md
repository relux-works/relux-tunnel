# Add cross-platform profile and key UI tests

## Description
Create maintainable iOS and macOS Page Object journeys for profile and key management using the shared test infrastructure. Capture and visually inspect step screenshots and keep synthetic secret fixtures out of attachments and logs.

## Scope
In scope: first profile, field validation, duplicate profile, selection, edit/discard, key import, encrypted/wrong-passphrase behavior, key generation, allowed public/private export branch, profile/key deletion, active conflict, repository and Keychain errors, relaunch persistence, identifiers, VoiceOver/keyboard assertions, snapshots, and screenshot extraction. Out of scope: host-trust prompts, live VPN connection, production keys, multi-device orchestration, and manual-only App Review evidence.

## Acceptance Criteria
1. macOS Page Objects cover one successful and every specified recovery path, with the iOS rows deferred with iOS under ADR-024 and re-armed unchanged when iOS resumes, with conditional waits and no fixed sleeps. 2. Tests assert field errors, action enablement, selected/active state, confirmations, retries, relaunch persistence, and zero secret text in labels, screenshots, logs, or result attachments. 3. Step screenshots are extracted and visually reviewed for orientation, layout, content, focus, text scaling, and black-screen failures; snapshot diffs are retained on failure. 4. Accessibility assertions cover identifiers, roles, labels, values, hints, focus order, keyboard commands on macOS, and representative Dynamic Type/text scaling. 5. The task records simulator/macOS destinations, versions, commands, xcresult paths, screenshot review evidence, and any physical-device rows deferred to M4 acceptance.
