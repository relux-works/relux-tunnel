# Implement the support-export redaction and manifest pipeline

## Description
Implement a user-initiated pipeline that snapshots approved diagnostic categories, reapplies the documented redaction pass, creates a human-readable manifest, enforces size limits, and cleans protected temporary artifacts on success, cancellation, expiration, or failure.

## Scope
In scope: explicit request, selected categories, immutable input snapshot, defense-in-depth redaction, deterministic JSON/text formats, schema/build/device/OS/source metadata allowed by contract, category manifest, file names, archive generation, byte/count limits, progress/cancellation, Data Protection/temp permissions, collision handling, cleanup, export audit event, and tests. Out of scope: automatic upload, support ticket creation, packet capture, destination/DNS data, production secrets, UI, and retention after the user moves the file.

## Acceptance Criteria
1. Export starts only after an explicit request and produces exactly the previewed categories plus a manifest describing schema, timestamps, versions, redactions, limits, and omitted categories. 2. A defense-in-depth redaction scan rejects rather than exports any prohibited key/passphrase/payload/DNS/destination/full-address/shell-input marker, including nested, encoded, malformed, and oversized fixtures. 3. Output uses deterministic bounded formats and protected temporary files; cancel, disk full, archive failure, app background, share/save cancel, and timeout remove all task-owned temporary artifacts. 4. The pipeline never performs network I/O or analytics and does not retain a hidden copy after platform handoff. 5. Unit/integration/golden/property tests verify manifest parity, category selection, redaction idempotence, limits, cleanup, reproducibility, and successful inspection on both platforms.
