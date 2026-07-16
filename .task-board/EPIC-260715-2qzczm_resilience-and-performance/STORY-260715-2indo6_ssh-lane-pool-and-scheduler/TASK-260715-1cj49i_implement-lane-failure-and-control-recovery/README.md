# Implement lane-local failure and control-lane recovery handoff

## Description
Implement lane-failure handling that stops new assignment on the failed lane, deterministically closes or drains its channels, re-establishes eligible capacity without migration, and routes lane-A loss through truthful relay, DNS, and degraded capability transitions.

## Scope
In scope: transport, keepalive, rekey, channel-open, server-close, and local-cancel failure events; failure generation; assignment disable; existing channel termination semantics; optional-lane retry; lane-A relay and control invalidation; M2 degraded or failed handoff based on safe DNS; bounded retry ownership shared with reconnect; memory admission; duplicate and late events; metrics. Out of scope: physical-path selection, preserving TCP byte streams across failed SSH sessions, rebuilding routes, relay-only reprobe implementation, host-key auto-accept, or retrying terminal authentication errors.

## Acceptance Criteria
1. The first current failure event atomically makes a lane ineligible before a new channel can be assigned and records one finite privacy-safe reason. 2. Existing channels on a failed transport receive the documented deterministic error and cleanup and are never migrated or replayed on another lane. 3. Optional-lane loss can restore only admitted replacement capacity, while lane-A loss invalidates control and relay state and publishes degraded only when the current safe-DNS and mandatory TCP predicates remain true. 4. Host-key, credential, authentication, and profile-generation failures do not enter an infinite lane retry, and path-level failures are handed to the reconnect owner once. 5. Fault tests cover every failure source, simultaneous lanes, duplicate callbacks, lane-A plus DNS loss, memory denial, stop races, recovery, snapshot ordering, and zero task, channel, session, or timer growth.
