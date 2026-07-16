# Build the macOS onboarding and system-approval journey

## Description
Build the keyboard-accessible macOS first-run/resume journey explaining the self-hosted product, SSH prerequisites, profile/key setup, host trust, approved privacy disclosure, VPN/system approval, first connection, capability result, and help/recovery while remaining distinct from legacy SOCKS behavior.

## Scope
In scope: welcome/product model, prerequisites, profile/trust handoff, privacy acknowledgement, manager/system approval steps, connect, full/degraded/failure completion, progress, back/resume/reset, settings/help, approved legacy migration/coexistence branch, window/menu integration, keyboard commands, focus, VoiceOver, text scaling, reduced motion, localization, identifiers, and screenshots. Out of scope: legacy system-ssh controls, remote host provisioning, release notarization, App Store/TestFlight, arbitrary SSH config import, and duplicated feature internals.

## Acceptance Criteria
1. A new Mac user can complete or resume the journey using pointer or keyboard and system approval guidance matches the actual Network Extension flow and current product target. 2. Legacy coexistence/migration messaging and actions exactly follow the approved decision and never silently replace defaults, keys, release identity, or manual SOCKS behavior. 3. Profile/trust/privacy/approval/connect/capability handoffs, app quit/relaunch, denial, failure, reset, and help return to deterministic valid steps without stopping an already active provider unintentionally. 4. VoiceOver, tab/focus order, standard keyboard actions, text scaling, contrast, reduced motion, localization expansion, and shared identifiers pass. 5. Native macOS Page Object/snapshot fixtures cover first run, permission/system approval, migration branch, full/degraded/failure, relaunch/quit, recovery, and long-copy visual inspection.
