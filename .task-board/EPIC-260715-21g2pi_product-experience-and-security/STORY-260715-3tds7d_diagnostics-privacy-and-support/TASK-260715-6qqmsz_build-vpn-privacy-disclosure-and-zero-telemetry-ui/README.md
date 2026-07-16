# Build VPN privacy disclosure and zero-telemetry UI

## Description
Build the approved disclosure shown before first VPN enablement and the persistent settings/privacy surfaces. Explain on-device processing, the user-controlled SSH exit, observer boundaries, system exclusions, diagnostic retention, support export, and zero baseline analytics/traffic telemetry.

## Scope
In scope: versioned approved copy keys, first-enable acknowledgement, expanded privacy view, settings access, exit-host/access-network/Relux Works roles, compatible/fail-closed system exclusions, diagnostics categories, retention/deletion controls, support-export link, future telemetry boundary, copy version changes, accessibility, localization, identifiers, and tests. Out of scope: public website hosting, regional licensing decision, consent for future telemetry, App Store metadata, implementation of diagnostics/export, and legal text improvisation.

## Acceptance Criteria
1. The first owned-manager enable action is gated until the current approved disclosure version is presented and explicitly acknowledged; viewing alone, dismissing, or app relaunch does not imply consent. 2. Copy states that the user controls the SSH host, the exit host can observe destination metadata/plaintext without end-to-end encryption, access networks see SSH metadata, and Relux Works is not in the baseline traffic path. 3. The UI accurately names Apple system exclusions, compatible/fail-closed limitations, zero baseline analytics/traffic telemetry, local/support retention, deletion, and user-initiated export. 4. Acknowledgement stores only disclosure version/time and no traffic data; updated material copy triggers the contract-approved re-presentation behavior. 5. iOS/macOS UI, snapshot, localization, and accessibility tests cover first enable, dismiss, acknowledge, relaunch, updated version, settings revisit, deletion navigation, and long-copy readability.
