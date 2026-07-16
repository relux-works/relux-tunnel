# Build empty, error, help, and settings recovery surfaces

## Description
Build the cross-feature recovery and help surfaces that connect users from empty or failed states to the exact supported corrective action. Reuse finite domain errors and approved copy rather than exposing raw implementation failures.

## Scope
In scope: no profile, no key, invalid profile, import/generation errors, permission denial, first-use/changed trust, auth/passphrase, host unreachable, tunnel setup, degraded limitations, reasserting, failed route/DNS, unsupported policy, provider/version unavailable, diagnostics/export errors, onboarding/migration interruption, settings/help navigation, retry/cancel/reset, offline-safe content, accessibility, localization, identifiers, and screenshots. Out of scope: new protocol behavior, arbitrary troubleshooting shell commands, password auth, silent trust, automatic data deletion, and release support backend.

## Acceptance Criteria
1. Every finite M4 error/reason maps to one accessible title, explanation, supported primary/secondary action, and destination owner; unknown errors remain privacy-safe and non-speculative. 2. Recovery actions preserve current profile/trust/privacy/session generations, prevent duplicate/racy commands, and never bypass disclosure, trust, Keychain, or fail-closed safety. 3. Empty and interrupted onboarding/migration states make the next valid action obvious and retain or discard data only with the contract-approved confirmation. 4. Help content accurately describes self-hosting, host visibility, system exclusions, full/degraded limits, privacy/support behavior, and escalation artifacts without unsupported claims or secrets. 5. Snapshot/Page Object/accessibility tests cover every mapping, navigation/return, retry failure, long localization, VoiceOver/keyboard, text scaling, focus, and screenshot review.
