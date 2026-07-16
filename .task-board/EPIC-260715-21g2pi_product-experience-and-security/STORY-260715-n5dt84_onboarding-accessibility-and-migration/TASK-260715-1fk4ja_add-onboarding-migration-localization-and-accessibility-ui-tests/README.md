# Add onboarding, migration, localization, and accessibility UI tests

## Description
Create maintainable iOS and macOS Page Object journeys for first run/resume, privacy/permission, approved legacy migration, empty/error recovery, localization, and assistive-technology behavior. Capture and visually inspect all critical steps.

## Scope
In scope: fresh install, resume after each step, back/reset, profile/trust handoffs, disclosure dismiss/acknowledge/update, permission denial, full/degraded/failure completion, help, legacy no-install/coexist/migrate/retire fixtures, interruption/idempotency/rollback, launch locales, pseudo-localization, long text, right-to-left rows if approved, VoiceOver, keyboard, focus, text scaling, contrast, reduced motion, identifiers, screenshots, and snapshot diffs. Out of scope: real production credentials, App Store submission, packet-performance validation, and unsupported locale translations.

## Acceptance Criteria
1. Page Objects cover every onboarding state/transition and approved migration branch on both platforms with deterministic fixtures, typed launch arguments, conditional waits, and no sleeps. 2. Tests prove privacy acknowledgement precedes first enable, permission and feature handoffs resume correctly, migration is explicit/idempotent/recoverable, and no safety gate is bypassed. 3. Locale/pseudo/expansion rows detect missing/stale keys, placeholder errors, clipping, misplaced fingerprint/technical text, privacy-copy mismatch, and required RTL defects. 4. VoiceOver and macOS keyboard journeys complete the primary product flow; focus, roles, values, errors, announcements, scaling, contrast, motion, and secure-field privacy pass. 5. Extracted screenshots/snapshot diffs are visually reviewed and the TASK-ID-scoped outcome records environments, commands, xcresults, migration fixtures, locale/accessibility matrix, and redacted evidence.
