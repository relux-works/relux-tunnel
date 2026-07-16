# Implement the bounded privacy-safe diagnostic event store

## Description
Implement a shared diagnostic event pipeline for containing apps and packet-tunnel providers that accepts only contract-approved typed fields, applies redaction before persistence, rotates within strict limits, and supports deletion. Keep the live provider independent from the containing app.

## Scope
In scope: typed event API, schema validation, pre-persistence redaction, Data Protection/App Group location if approved, per-generation records, timestamps/states/lane IDs/aggregates/errors/memory/algorithms/relay identity, byte and record ceilings, rotation, expiration, concurrent app/provider writers, crash-safe atomicity, app relaunch, deletion, privacy-safe health metrics, injectable storage, and tests. Out of scope: packet/DNS/destination data, untyped log strings as export input, analytics upload, OS unified-log scraping, provider dependence on app availability, and UI.

## Acceptance Criteria
1. The API cannot represent prohibited traffic/credential fields and rejects unknown, oversized, malformed, or wrong-version events before persistence. 2. Redaction occurs before bytes reach disk or shared messages; stored files use the approved protection and access boundary and never contain raw addresses beyond allowed family-level facts. 3. Rotation/expiry enforce documented record, byte, age, and generation ceilings under concurrent app/provider writes, crash interruption, low disk, clock changes, and relaunch. 4. Provider collection continues within bounds when the app is absent, and app deletion/retention actions coordinate safely without corrupting active provider writes. 5. Unit/integration tests plus artifact scans cover every approved/prohibited field, concurrency, corruption, limits, rotation, expiration, deletion, repeated cycles, and cleanup.
