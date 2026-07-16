# Publish versioned and stable macOS assets with authenticated GitHub access

## Description
Publish immutable versioned macOS artifacts and update the stable ReluxProxy.dmg asset on the private GitHub repository using least-privilege authentication, digest verification, atomic replacement semantics, and resumable failure handling.

## Scope
In scope: validated tag and release identity, GitHub Environment token, release creation or update, versioned DMG and checksums, stable ReluxProxy.dmg and checksum, provenance and compliance links or assets, content type, labels, overwrite prevention for immutable names, staged stable replacement, API response verification, authenticated download test, unauthenticated-access expectation, idempotent rerun, partial failure cleanup, retention, and withdrawal. Out of scope: making the private repository public, embedding credentials in URLs or apps, rebuilding assets during upload, iOS distribution, and silently overwriting a versioned asset.

## Acceptance Criteria
1. Upload consumes only evidence-approved artifact digests and an immutable versioned asset can never be overwritten by a different digest. 2. The stable asset update has a documented no-mixed-version sequence, verifies remote size and SHA-256 after upload, and always resolves to the same candidate as the versioned release. 3. An authenticated GitHub API or client download retrieves the stable and versioned assets and verifies checksums; documentation does not assume anonymous private-repository access. 4. Tokens are minimum scope, environment protected, masked, unavailable to forks, and removed from URLs, logs, metadata, caches, and artifacts. 5. Network failure, duplicate tag, existing conflicting asset, partial upload, API rate limit, cancellation, stable-update failure, checksum mismatch, rerun, and withdrawal produce explicit recoverable states without a false successful release.
