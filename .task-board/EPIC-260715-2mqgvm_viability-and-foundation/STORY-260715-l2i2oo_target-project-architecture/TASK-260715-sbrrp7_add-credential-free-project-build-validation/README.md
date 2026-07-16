# Add credential-free generated-project build validation

## Description
Add the local and pull-request validation surface for deterministic generation, every generated target, shared tests, relay target shells, native packaging seams, entitlement-file expectations, and legacy coexistence without requiring production signing credentials.

## Scope
In scope: pinned-tool bootstrap; generation drift check; macOS host and provider build; iOS simulator host and provider build; device archive or build with signing disabled where supported; ReluxTunnelCore and harness tests; relay matrix smoke; static entitlement and embedding inspection; legacy SwiftPM regression; artifact and log locations. Out of scope: production certificates, physical-device Gate P0 repetition, TestFlight, notarization, DMG release publication, full SBOM policy, and packet or SSH feature tests.

## Acceptance Criteria
1. One documented local entry point and equivalent pull-request jobs run deterministic generation, all credential-free builds, shared Swift Testing suites, relay smoke tests, native linkage checks, and legacy regression checks. 2. Jobs fail on generator drift, missing target or scheme, invalid embedding, entitlement-file mismatch, unpinned dependency input, disallowed linkage, or legacy build regression. 3. Logs and artifacts identify source revision, tool versions, SDKs, deployment targets, and invoked schemes without exposing secrets. 4. Signing-required checks are clearly separated and skipped only with an explicit reason, never reported as passed. 5. The validation completes from a clean checkout using documented prerequisites.
