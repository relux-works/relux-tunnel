# Produce the iOS distribution acceptance verdict

## Description
Perform the independent end-to-end iOS distribution gate and publish a verdict over the exact archive, TestFlight build, physical-device results, privacy and export checks, provenance, App Store preflight, and rollback readiness.

## Scope
In scope: exact source and App Store Connect build ID, archive and export digests, bundle topology, profiles, entitlements, versions, relay integrity, privacy manifests, required-reason APIs, symbols, export record, provenance, TestFlight processing and group, physical matrix, accessibility, lifecycle, diagnostics, withdrawal rehearsal, secret audit, evidence completeness, and pass or fail index. Out of scope: implementing fixes, accepting simulator-only proof, submitting App Review, legal or regional approval, macOS distribution, and overriding an Apple or security failure.

## Acceptance Criteria
1. The auditor independently verifies the candidate identity from source and archived bytes through App Store Connect build ID and named-device TestFlight installation. 2. Exact host and extension profiles, entitlements, versions, architectures, relay resources, privacy manifests, symbols, export answers, and provenance pass without development-only or extra rights. 3. TestFlight processing, intended group distribution, physical lifecycle and accessibility matrix, server preflight, evidence retention, and withdrawal or credential recovery rehearsal all pass or produce a blocking result. 4. Logs, archives, symbols, reports, caches, and evidence contain no private certificate key, issuer key, password, production SSH credential, or user traffic. 5. A TASK-ID-scoped verdict lists every gate, environment, command, artifact digest, build ID, result, anomaly, residual risk, and blocker and is required before App Review submission.
