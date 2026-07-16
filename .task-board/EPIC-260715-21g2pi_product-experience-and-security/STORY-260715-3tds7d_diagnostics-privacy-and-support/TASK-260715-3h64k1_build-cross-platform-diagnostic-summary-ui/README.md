# Build the cross-platform diagnostic summary UI

## Description
Build accessible iOS and macOS summaries that help a user understand tunnel lifecycle, current/historical capability, aggregate health, safe errors, algorithms, relay identity, and resource measurements without showing traffic or credentials.

## Scope
In scope: current versus historical/unavailable labeling, state transitions, full/degraded capability, finite errors, lane IDs, aggregate flow/drop counts, memory measurements, negotiated algorithms, relay build identity, timestamps/duration, refresh, provider unavailable, copy-safe summary, support export entry, delete entry, navigation, localization, identifiers, accessibility, and snapshots. Out of scope: raw events by default, destinations, DNS names, full addresses, packet samples, developer console, live charts requiring telemetry, and export assembly.

## Acceptance Criteria
1. Every displayed value belongs to an approved contract field and current data is visibly distinguished from stale, historical, partial, and unavailable data. 2. The UI cannot reveal prohibited traffic/credential fields through labels, accessibility values, copy actions, error text, or debug descriptions. 3. Full/degraded/reasserting/failure summaries agree with the connection presentation model and provide only supported help/export/delete actions. 4. Refresh, provider absent, protocol skew, corrupt local data, empty history, partial results, and deletion have actionable deterministic states. 5. iOS/macOS snapshot and accessibility fixtures cover long values, localization expansion, VoiceOver/keyboard/focus, text scaling, contrast, reduced motion, and screenshot review.
