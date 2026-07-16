# Build the iOS onboarding and VPN-permission journey

## Description
Build the accessible iOS first-run/resume journey explaining the self-hosted product, SSH prerequisites, profile/key setup, host trust, approved privacy disclosure, system VPN permission, first connection, capability result, and help/recovery.

## Scope
In scope: welcome/product model, requirements checklist, SSH host guidance, profile/trust handoff, current privacy acknowledgement, connect/permission trigger, permission denial guidance, full/degraded/failure completion, progress, back/resume/reset, settings/help links, migration branch where applicable, Dynamic Type, VoiceOver, focus, reduced motion, identifiers, localization, and screenshots. Out of scope: duplicating editors/trust/dashboard internals, provisioning a remote host, scanning SSH servers, TestFlight/App Review, and promising unsupported traffic coverage.

## Acceptance Criteria
1. A new user can traverse every required step with accurate copy and is never asked for VPN permission before an eligible profile and current privacy acknowledgement exist. 2. Profile, trust, permission, connection, capability, and diagnostic/help handoffs return to the correct resumable step and do not duplicate or bypass their own safety controls. 3. Denial, cancellation, no key/profile, changed key, auth failure, offline host, degraded mode, mandatory failure, relaunch, and reset have actionable finite outcomes. 4. VoiceOver order/labels/values/hints, supported Dynamic Type, contrast, focus, reduced motion, link behavior, and shared identifiers pass on representative phone sizes. 5. Page Object/snapshot fixtures cover first run, each recovery, resume, completed revisit, disclosure update, and long localized copy with visual screenshot inspection.
