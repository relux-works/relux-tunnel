# Add diagnostics redaction, export, bounds, and zero-telemetry security tests

## Description
Build adversarial automated coverage for typed diagnostics, persistence, provider messaging, aggregation, export, cleanup, and baseline network silence. Make prohibited-data fixtures fail the pipeline and scan every generated artifact.

## Scope
In scope: approved/prohibited field matrices, nested/encoded/unicode/oversized/malformed inputs, redaction property/fuzz tests, schema versions, event rotation/retention, concurrent writers, message bounds, stale generations, export manifest/golden data, temporary cleanup, crash/cancel/failure injection, source/dependency configuration audit for analytics SDKs, runtime outbound-network sentinels, logs/crash annotations/artifact scanning, and repeated cycles. Out of scope: actual user traffic, production credentials, UI pixels, future opt-in telemetry, and public policy review.

## Acceptance Criteria
1. Each prohibited credential/traffic/address/DNS/destination marker is rejected or irreversibly redacted before persistence, messaging, crash annotation, preview, and export; artifact scans verify absence. 2. Property/fuzz and boundary tests prove parsing/redaction/export remain bounded for malformed, recursive, encoded, huge, unknown-version, and concurrent inputs. 3. Rotation, retention, deletion, provider absent, version skew, cancellation, disk failure, archive failure, and repeated export cycles return tasks/files/handles/memory to baseline. 4. Dependency/config/source audit plus controlled runtime network sentinels detect any analytics or traffic-telemetry SDK, endpoint, upload, or background request in the baseline product. 5. The task publishes exact commands, seeds, corpus references, artifact inventory, and redacted results without copying prohibited fixture content into board resources.
