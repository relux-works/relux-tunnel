# Verify SSH authentication inside physical packet-tunnel providers

## Description
Run one profile-driven SSH bootstrap in the development-signed M1 packet-tunnel provider on a named physical iPhone and Apple-silicon Mac. Prove shared Keychain access, mandatory host verification, public-key authentication, actual endpoint capture, cancellation, and privacy-safe evidence in the real extension context.

## Scope
In scope: supported physical devices and OS versions, approved test host, non-production test key references, approved fingerprint, successful Ed25519 and fallback coverage across the two platforms where supported, deliberate changed-key or alternate fixture rejection, user stop during bootstrap, redacted provider logs, and resource observations. Out of scope: full TCP or DNS forwarding matrix, App Store distribution, production credentials, trust UI, path switching, long rekey tests, and unrelated device logs.

## Acceptance Criteria
1. Evidence records device classes, OS and Xcode, source and dependency revisions, profile generation, public algorithms and fingerprints, endpoint family, bundle versions, non-secret signing metadata, and timestamp. 2. Both providers access only their approved shared Keychain items, verify the host before auth, authenticate, and report the actual connected endpoint family without exposing the address. 3. A changed-key fixture fails before user authentication and leaves no active SSH session or installed default route. 4. Stop during resolve, host verification, Keychain access where controllable, and authentication releases sockets, tasks, secret containers, and provider start completion. 5. A TASK-ID-scoped runbook and redacted result bundle lets another authorized operator repeat the tests without receiving credentials.
