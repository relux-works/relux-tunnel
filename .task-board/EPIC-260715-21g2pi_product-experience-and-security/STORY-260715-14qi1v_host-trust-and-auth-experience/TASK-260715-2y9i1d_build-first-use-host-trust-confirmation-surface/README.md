# Build the first-use host-trust confirmation surface

## Description
Build the cross-platform first-use review surface that explains why host verification is required, shows the exact canonical host, algorithm, and complete SHA-256 fingerprint, and requires an explicit accessible trust action or cancellation before retry.

## Scope
In scope: shared SwiftUI content where practical, iOS sheet/navigation presentation, macOS sheet/window presentation, complete non-truncated fingerprint with copy action, algorithm and host, provenance explanation, verification guidance, high-friction trust button, cancel, help, loading/error states, keyboard and VoiceOver behavior, identifiers, text scaling, and screenshots. Out of scope: changed-key replacement, automatic approval, QR verification, key import, password auth, and hiding fingerprint details behind disclosure by default.

## Acceptance Criteria
1. The full SHA-256 fingerprint, key algorithm, and canonical host are visible and accessible without truncation; copy copies only the fingerprint and confirms the action. 2. Trust is a distinct explicit action with clear consequence, cancel leaves no approved record, and dismiss/back cannot implicitly approve or immediately reconnect. 3. Unsupported version/algorithm, stale request, repository conflict, and save failure disable trust and provide safe recovery. 4. iOS and macOS layouts support VoiceOver, keyboard on macOS, logical focus, supported text scaling, contrast, reduced motion, and stable shared identifiers. 5. Page Object/snapshot fixtures cover default, help, copied, saving, conflict, error, and cancel states and screenshots contain no credential material.
