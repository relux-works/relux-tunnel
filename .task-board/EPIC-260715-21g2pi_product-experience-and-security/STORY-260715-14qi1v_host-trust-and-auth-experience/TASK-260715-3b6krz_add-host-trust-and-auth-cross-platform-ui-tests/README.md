# Add cross-platform host-trust and authentication UI tests

## Description
Create iOS and macOS Page Object journeys for first-use trust, changed-key recovery, and authentication/passphrase failures. Capture and visually inspect screenshots while proving no user gesture or lifecycle event can imply trust.

## Scope
In scope: first-use review/copy/trust/cancel, repeat connection no prompt, changed-key old/new evidence, replace confirmation, stale/conflict errors, missing/inaccessible key, secure passphrase, auth rejection, unsupported algorithm, retry/cancel, relaunch/background, identifiers, VoiceOver, keyboard, text scaling, snapshots, and artifact redaction. Out of scope: live production hosts, password auth, connection performance, and App Review submission.

## Acceptance Criteria
1. Page Objects exercise successful and cancelling first-use paths, changed-key block/replace paths, every auth recovery mapping, and relaunch/background transitions with conditional waits. 2. Tests assert complete fingerprint accessibility, distinct first-use versus changed-key semantics, disabled unsafe actions, explicit confirmations, and fresh retry after durable approval only. 3. Secure fields have no exposed value in the accessibility tree or screenshots and automated artifact scans find no synthetic private key or passphrase marker. 4. Extracted step screenshots and snapshot diffs are visually reviewed on representative iOS and macOS layouts for focus, scaling, truncation, contrast, and black-screen/orientation errors. 5. The task records test destinations, fixture generations, commands, xcresult/screenshots, accessibility evidence, and redacted outcomes.
