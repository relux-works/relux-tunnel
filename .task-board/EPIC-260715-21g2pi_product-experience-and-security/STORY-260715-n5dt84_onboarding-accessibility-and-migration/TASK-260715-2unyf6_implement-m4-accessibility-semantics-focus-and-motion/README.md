# Implement M4 accessibility semantics, focus, scaling, contrast, and motion

## Description
Apply release-grade accessibility behavior across every M4 profile, key, trust, connection, policy, diagnostics, privacy, support, onboarding, migration, help, and error surface on iOS and macOS. Use the shared identifier infrastructure without making test identifiers substitute for user semantics.

## Scope
In scope: labels, roles, values, hints, headings, groups, status announcements, errors, secure fields, fingerprint reading/copy, progress, modal focus trapping/return, keyboard navigation and commands, pointer targets, Dynamic Type/macOS text scaling, layout reflow, contrast, differentiate-without-color, reduced motion, reduce transparency where relevant, localization pronunciation/context, Accessibility Inspector checks, and fixes. Out of scope: inventing product copy, unsupported assistive technologies, visual redesign unrelated to accessibility, and test-only hidden controls.

## Acceptance Criteria
1. An accessibility inventory maps every interactive/status/error element to a meaningful role, label, value, hint, group, identifier, focus behavior, and platform keyboard action where applicable. 2. VoiceOver can complete configure, key action, trust/cancel, connect/degraded/failure, diagnostics/export/delete, privacy, onboarding, migration, and disconnect journeys without inaccessible gestures or secret-value exposure. 3. macOS journeys are fully keyboard operable with deterministic focus/modal return and no pointer-only or status-item-only action. 4. Supported text scaling/Dynamic Type, long localization, contrast, color-independent meaning, reduced motion, and reduced-transparency behavior avoid clipping, overlap, lost controls, and unsafe animation dependence. 5. Automated checks plus manual Accessibility Inspector/VoiceOver/keyboard evidence on named iPhone and Mac record issues, fixes, screenshots, and pass/fail by surface.
