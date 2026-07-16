# Build the iOS VPN connection dashboard

## Description
Build the primary iOS surface for profile selection, connect/disconnect, lifecycle and capability status, permission handling, details, and recovery using the shared presentation model and system-standard patterns.

## Scope
In scope: selected profile summary, no-profile route, main connect/disconnect control, status label/value, progress, full/degraded/reasserting/failed badges, permission request and denial guidance, reason/details navigation, profile/settings/diagnostics links, app background/relaunch refresh, Dynamic Type, VoiceOver, focus, reduced motion, identifiers, snapshots, and safe errors. Out of scope: profile editor internals, trust sheet internals, diagnostics content, packet/runtime logic, custom VPN indicator, and release submission.

## Acceptance Criteria
1. Every presentation-model state has one unambiguous accessible visual treatment and only the contract-allowed primary/secondary actions. 2. Connect identifies the selected profile, triggers system permission through the manager flow, prevents duplicate commands, and transitions from authoritative observations rather than animation completion. 3. Disconnect remains available and clearly in progress until the system confirms stop; app background/relaunch restores current session/capability state without interrupting forwarding. 4. Degraded names missing UDP and preserves connected wording, reasserting communicates temporary recovery, and failed provides the finite safe remediation without implying a physical fallback. 5. Representative phone snapshots and Page Object fixtures pass supported Dynamic Type, VoiceOver order/values/hints, contrast, reduced motion, orientation/layout, and black-screen inspection.
