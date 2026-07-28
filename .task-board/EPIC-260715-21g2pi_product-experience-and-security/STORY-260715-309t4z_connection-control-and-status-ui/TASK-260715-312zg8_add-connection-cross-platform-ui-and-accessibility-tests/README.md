# Add cross-platform connection UI and accessibility tests

## Description
Create iOS and macOS Page Object journeys for VPN controls, status, capability details, policy settings, profile switching, failure recovery, app lifecycle, and accessibility. Capture and visually inspect each significant state.

## Scope
In scope: no-profile, selected profile, permission flow fixtures, connect, disconnect, duplicate taps, full, degraded, reasserting, failed reasons, stale/unsupported snapshot, profile/policy edit safeguards, dashboard/detail parity, app relaunch, macOS quit continuity, identifiers, VoiceOver, keyboard, text scaling, reduced motion, snapshots, and screenshots. Out of scope: relying on Simulator to prove real Network Extension permission/system indicator, packet leak testing, production hosts, and App Review submission.

## Acceptance Criteria
1. Page Objects drive every dashboard, details, settings, confirmation, and recovery path on macOS, with the iOS rows deferred under ADR-024, with condition-based waits and deterministic session fixtures. 2. Assertions prove allowed controls and copy for every state, full/degraded truthfulness, active-versus-selected profile, policy disclosures, and no contradiction between macOS menu/window surfaces. 3. VoiceOver labels/values/status announcements, macOS keyboard navigation/commands, focus order, text scaling, contrast, reduced-motion fixtures, and stable identifiers pass. 4. Extracted screenshots and failed snapshot diffs are visually reviewed for orientation, progress/layout, long text, modal focus, status parity, and black screens. 5. The task records destinations, OS/Xcode, commands, xcresults, screenshot evidence, and the physical-only rows handed to the named-device verification task.
