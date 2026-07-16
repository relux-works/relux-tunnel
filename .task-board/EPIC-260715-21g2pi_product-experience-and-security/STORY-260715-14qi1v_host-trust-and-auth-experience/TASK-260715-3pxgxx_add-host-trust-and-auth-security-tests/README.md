# Add host-trust and authentication security tests

## Description
Build deterministic unit and integration coverage for the M4 trust write path, coordinator, M1 policy handoff, authentication errors, passphrase handling, multi-lane identity consistency, and redaction using controlled OpenSSH evidence and synthetic credentials only.

## Scope
In scope: first use, approved reuse, changed/revoked key, algorithm changes, explicit replacement, stale generations, provenance/timestamps, lane identity mismatch, provider-before-auth ordering, app suspension/termination, duplicate requests, profile conflict, passphrase lifecycle, Keychain errors, auth rejection, retry/cancel, serialization bounds, logs/diagnostics scans, and repeated cycles. Out of scope: visual UI assertions, production hosts/credentials, SSH engine conformance already owned by M0/M1, throughput, and release signing.

## Acceptance Criteria
1. Tests prove host verification precedes authentication for first-use, approved, changed, revoked, and lane-mismatch cases and no failure path performs a silent accept. 2. Repository/coordinator tests cover compare-and-swap replacement, stale evidence, duplicate actions, concurrent edits, app relaunch, cancellation, and consistent generation use across all lanes. 3. Passphrase and Keychain fixtures prove secret lifetime/clearing and prohibited fields never reach profiles, messages beyond the approved secure channel, logs, diagnostics, screenshots, or outcomes. 4. Integration fixtures show an approved repeat connection succeeds, a changed key stops before auth, replacement requires explicit publication plus fresh retry, and identity disagreement terminates the session. 5. Repeated scenarios return prompts, tasks, buffers, Keychain handles, and connection resources to baseline and publish redacted commands/results.
