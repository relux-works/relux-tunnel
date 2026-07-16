# Allocate the iOS marketing version and monotonic build number

## Description
Implement an idempotent version-allocation step that validates the release tag and candidate, reserves or selects a monotonic App Store Connect build number, and propagates both versions consistently to host, extension, archive, relay evidence, and release notes.

## Scope
In scope: semantic marketing version, CFBundleShortVersionString, CFBundleVersion, host-extension equality, App Store Connect existing-build query, monotonic allocation, concurrent-release serialization, prerelease policy, dry run, retry, source and tag binding, generated-project input, artifact names, and evidence. Out of scope: selecting product launch timing, changing relay protocol version, uploading a build, editing versions after archive, and reusing a rejected build number for different bytes.

## Acceptance Criteria
1. The allocator validates an approved clean candidate tag and chooses one marketing version and a monotonically valid unused build number under protected serialized release control. 2. Host, extension, archive metadata, export metadata, release notes, evidence, and App Store Connect query all agree on both values before signing. 3. Retries for the same immutable candidate return the same reserved values while a different candidate cannot reuse them. 4. Concurrent dispatch, existing builds, rejected or expired builds, version regression, malformed tag, host-extension mismatch, and partial prior runs have deterministic safe outcomes. 5. Unit or harness fixtures cover first build, patch, prerelease, duplicate, race, retry, rollback candidate, App Store Connect outage, and wrong-source cases without production mutation.
