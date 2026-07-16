# Build the macOS VPN connection dashboard

## Description
Build the native macOS menu-bar and/or window/settings connection experience selected by the target architecture. Provide keyboard-accessible profile selection, connect/disconnect, authoritative status, capability details, permission guidance, and recovery without reusing legacy SOCKS behavior.

## Scope
In scope: status item/menu and main window responsibilities, selected profile, connect/disconnect commands, lifecycle/capability status, system approval guidance, details, profile/settings/diagnostics navigation, app relaunch/quit behavior, keyboard shortcuts, menu validation, focus order, VoiceOver, text scaling, reduced motion, identifiers, snapshots, and safe errors. Out of scope: legacy SOCKS process controls, system SSH launch, provider implementation, Developer ID packaging, and release migration.

## Acceptance Criteria
1. The chosen macOS surfaces have one documented command/status authority and show the same contract states and allowed actions as iOS without contradictory menu versus window values. 2. Pointer, keyboard, menu command, status-item, relaunch, and quit interactions reconcile with NETunnelProviderSession; quitting the UI does not imply or cause tunnel stop unless the user explicitly selected disconnect. 3. System extension/VPN approval, invalid configuration, disconnect progress, degraded capability, reasserting, and failures have actionable platform-appropriate guidance. 4. VoiceOver roles/labels/values/help, deterministic focus and tab order, standard keyboard commands, text scaling, contrast, reduced motion, and shared identifiers pass the defined checks. 5. Native macOS snapshots and XCUITest fixtures cover menu/window parity, every state, duplicate commands, permission denial, relaunch, app quit continuity, and recovery.
