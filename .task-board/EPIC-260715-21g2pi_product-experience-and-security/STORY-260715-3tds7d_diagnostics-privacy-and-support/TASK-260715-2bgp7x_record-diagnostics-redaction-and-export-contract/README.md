# Record the diagnostics, redaction, and export contract

## Description
Produce the binding M4 data contract for runtime events, aggregate snapshots, local retention, app-extension transfer, redaction, user preview, support export, deletion, and zero-telemetry verification. Treat the prohibited-data list as an enforceable schema boundary.

## Scope
In scope: approved event/snapshot fields, prohibited fields, field types and bounds, timestamps/generations, lane identifiers, aggregate counts, errors, memory, algorithms, relay identity, address-family redaction, store protection/retention/rotation, versioned provider messages, export categories/manifest/limits, redaction order, temporary files, preview, deletion, diagnostics copy inputs, crash annotations, tests/fuzz targets, and audit hooks. Out of scope: payload or traffic capture, destination/DNS logging, third-party analytics/crash SDK selection, public privacy-policy hosting, legal approval, and product UI layout.

## Acceptance Criteria
1. A TASK-ID-scoped schema enumerates every permitted field and representation plus explicit maximum sizes/counts/retention and rejects unspecified fields by default. 2. Keys, passphrases, packet payloads, DNS names, destination hostnames/IPs, full local addresses, shell stdin, user traffic samples, and raw provider errors are prohibited across logs, stores, messages, crashes, previews, and exports. 3. Redaction is ordered, deterministic, idempotent, versioned, and applied before persistence/export with adversarial and property/fuzz vectors for encoded, nested, oversized, and malformed inputs. 4. Collection, rotation, app relaunch, provider unavailable, schema skew, export, cancellation, temporary-file cleanup, user deletion, and retention expiry have deterministic ownership and failure behavior. 5. The contract defines the exact baseline no-analytics/no-traffic-telemetry audit and downstream tasks without including real user data.
