# Implement automatic byte, time, and server rekey coordination

## Description
Implement one per-lane rekey coordinator that observes transferred bytes and elapsed stable time, honors server-initiated requests, serializes key exchange, pauses new-channel admission, preserves active channel state, and emits bounded metrics.

## Scope
In scope: configurable client byte and elapsed-time thresholds; monotonic clock; inbound server rekey; one in-flight exchange; threshold reset; simultaneous trigger coalescing; channel-open admission gate; active direct-tcpip and relay continuity; timeout and cancellation; selected adapter calls; privacy-safe counters and durations; deterministic fake-clock tests. Out of scope: choosing cryptographic algorithms, SSH engine fork work, lane replacement after failure, path reconnect, final threshold tuning, migrating channels, or logging traffic content.

## Acceptance Criteria
1. Exactly one rekey starts for a current lane when the first valid byte, time, or server trigger becomes eligible, and simultaneous triggers coalesce without losing a later required rekey. 2. New channel assignment pauses before key exchange and resumes only after current-generation success, while existing channel and relay state remains valid according to the selected engine contract. 3. Byte counters use overflow-safe monotonic accounting, elapsed thresholds use an injected monotonic clock, and successful thresholds reset at a documented boundary. 4. Timeout, cancel, lane close, provider stop, and stale completion produce one terminal coordinator event and release timers and admission gates. 5. Fake-clock and fake-transport tests cover all triggers, simultaneous triggers, long active traffic, repeated cycles, stop races, stale generations, metrics, and no timer or task growth.
