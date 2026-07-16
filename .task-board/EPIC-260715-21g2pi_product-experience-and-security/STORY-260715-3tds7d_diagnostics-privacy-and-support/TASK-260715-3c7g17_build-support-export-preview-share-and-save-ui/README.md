# Build support-export preview, share, and save UI

## Description
Build the user interaction that previews support-export categories and privacy notes, obtains explicit confirmation, shows progress, and hands the resulting file to iOS share or macOS save/share controls with cancellation and cleanup.

## Scope
In scope: category list and inclusion state, manifest preview, data-not-included explanation, estimated/current size, confirmation, progress, cancel, success, redaction/export failure, iOS activity view, macOS save/share panel, filename, overwrite/collision, task-owned file cleanup, recent-export deletion where applicable, accessibility, localization, identifiers, and tests. Out of scope: automatic upload, emailing support directly, ticket creation, retaining user-moved files, and export generation internals.

## Acceptance Criteria
1. Before generation the user sees every included category, excluded prohibited categories, retention/handling copy, and the exact manifest fields that will identify the bundle. 2. No export or platform handoff occurs without explicit confirmation; cancel at preview, generation, share, or save leaves no task-owned file. 3. iOS share and macOS save/share use standard platform surfaces, display only the sanitized filename, and handle overwrite, permission, disk, provider unavailable, and redaction rejection safely. 4. Success identifies where control passed to the user and offers deletion of app-retained temporary/history data without claiming deletion of external copies. 5. Page Object/snapshot/accessibility tests verify categories, confirmations, progress, cancellation, errors, cleanup, VoiceOver/keyboard, text scaling, and artifact parity with preview.
