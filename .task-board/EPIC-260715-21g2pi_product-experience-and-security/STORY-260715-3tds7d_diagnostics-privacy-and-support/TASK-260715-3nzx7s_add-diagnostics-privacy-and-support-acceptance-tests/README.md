# Add diagnostics, privacy, and support acceptance tests

## Description
Create cross-platform UI journeys and named-device acceptance evidence for disclosure gating, diagnostic summaries, support preview/export, deletion, app/provider lifecycle, accessibility, and zero-telemetry behavior.

## Scope
In scope: first-enable disclosure, dismiss/acknowledge/version update, settings revisit, diagnostics empty/current/historical/partial/error states, full/degraded parity, refresh, category preview, export success/cancel/failure, file inspection, delete, app relaunch/provider unavailable, iOS share/macOS save fixtures, identifiers, VoiceOver, keyboard, text scaling, screenshots, physical device checks, and network sentinel review. Out of scope: production traffic capture, public policy hosting, App Store submission, regional licensing, and support-ticket backend.

## Acceptance Criteria
1. Page Object tests prove current disclosure acknowledgement gates first enable and every diagnostics/export/delete state behaves per contract on iOS and macOS. 2. Export test artifacts match the preview/manifest, contain only synthetic approved fields, pass prohibited-marker scanning, and leave no temporary copy after cancel/delete or completed handoff cleanup. 3. Accessibility checks cover identifiers, labels/values/hints, status announcements, focus, macOS keyboard, text scaling, contrast, reduced motion, and long approved copy. 4. Extracted screenshots and snapshot diffs are visually reviewed for layout, truncation, modal focus, progress, errors, orientation, and black screens. 5. A TASK-ID-scoped redacted result records simulator/macOS and named physical-device environments, commands, xcresults, screenshots, inspected export hashes/categories, network-sentinel outcome, and pass/fail per row.
