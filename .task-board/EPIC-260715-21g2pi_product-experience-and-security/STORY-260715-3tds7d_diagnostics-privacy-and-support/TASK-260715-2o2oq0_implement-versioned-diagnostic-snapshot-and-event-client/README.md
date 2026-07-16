# Implement the versioned diagnostic snapshot and event client

## Description
Implement the containing-app client that requests current provider diagnostic/capability snapshots, reads retained approved events, validates versions/generations/bounds, and produces one presentation/export model without treating stale data as live state.

## Scope
In scope: versioned app messaging, timeout/cancellation, provider absent/stopped, message size limits, schema compatibility, current versus historical generation, event-store pagination/bounds, aggregation, deduplication, snapshot freshness, relaunch, safe partial results, error mapping, and injectable transport/store. Out of scope: provider snapshot production, event persistence, UI layout, export file creation, raw log retrieval, and live traffic inspection.

## Acceptance Criteria
1. The client accepts only supported size-bounded schemas, rejects malformed/unknown critical fields, and clearly labels current, historical, unavailable, and partial data. 2. Snapshot generation/freshness is validated against the system session and selected/active profile; stale data never drives current capability or status. 3. Timeout, app relaunch, provider stop, version skew, store corruption, duplicate events, and cancellation return deterministic privacy-safe partial/error states. 4. Aggregation preserves contract bounds, does not reconstruct destinations or raw addresses, and produces only approved presentation/export categories. 5. Swift tests cover messages, pagination, bounds, versions, generations, partial failures, relaunch, cancellation, and repeated client lifecycle with no observer/task growth.
