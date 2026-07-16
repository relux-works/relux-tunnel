# Build authentication and passphrase recovery UI

## Description
Build privacy-safe recovery surfaces for missing/inaccessible keys, passphrase-required or incorrect passphrase, public-key rejection, unsupported algorithms, Keychain access failure, and generic negotiation errors. Guide only actions that the product actually supports.

## Scope
In scope: finite M1 error mapping, profile/key navigation, optional prompt-each-time passphrase entry if approved, store/retry choice if approved, Keychain locked/unavailable guidance, missing key replacement, rejected key server guidance, unsupported algorithm explanation, retry/cancel, attempt limiting, secret-field accessibility/privacy, app background handling, identifiers, and tests. Out of scope: password-only SSH, revealing server auth banners containing sensitive data, agent forwarding, raw SSH error dumps, arbitrary shell commands, and trust replacement.

## Acceptance Criteria
1. Each supported error code maps to one stable title, safe detail, allowed actions, and retry classification; unknown codes use a non-speculative fallback. 2. Passphrase input uses secure entry, is excluded from observable state, screenshots, logs, crash annotations, and accessibility value, and clears on background, cancel, failure, success, and view destruction. 3. Keychain, missing-key, rejected-key, unsupported-algorithm, and negotiation errors never direct users to unsupported password auth or silent trust bypass. 4. Retry is gated by current profile/trust generation, bounded against accidental rapid repetition, and cancellation leaves the provider stopped safely. 5. Unit and cross-platform UI tests cover all mappings, secure field behavior, app lifecycle, retries, navigation, VoiceOver/keyboard, and redacted screenshots.
