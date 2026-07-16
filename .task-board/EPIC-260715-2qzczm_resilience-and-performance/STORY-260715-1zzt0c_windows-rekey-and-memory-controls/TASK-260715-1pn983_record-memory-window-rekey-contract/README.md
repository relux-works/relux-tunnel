# Record the cross-layer memory, window, and rekey contract

## Description
Produce the binding extension memory ledger and policy contract covering every bounded consumer, channel-window credit, rekey overlap, pressure state, ordered action, reconnect reservation, metric, and failure outcome.

## Scope
In scope: physical-footprint engineering target and device variance; packet socket buffers; HEV sessions, task stacks, TCP buffers, caches, and queues; SSH lanes, channels, advertised windows, pending writes, and key exchange; DNS and relay buffers; metrics; old and new reconnect transports; ledger units and ownership; reservation and release; soft, pressure, and critical states; action order; sampling semantics; typed refusal and stop; diagrams; M0 through M3 interfaces. Out of scope: claiming Apple memory guarantees, treating all advertised credit as allocated, implementation, final watermark numbers without evidence, jetsam-driven control, payload capture, or weakening safety gates.

## Acceptance Criteria
1. A TASK-ID-scoped ledger names every consumer, owner, unit, hard ceiling, current and peak accounting input, reservation lifetime, release event, and observability source, including reconnect overlap. 2. It defines window-credit accounting without asserting eager allocation and gives formulas for 32 KiB, 64 KiB, relay, and capped BDP candidates under a global budget. 3. Soft, pressure, and critical states have deterministic entry and exit rules, hysteresis, one ordered action table, stale or unavailable advisory-memory behavior, and no cached os_proc_available_memory value. 4. The contract specifies channel and lane admission, WINDOW_ADJUST withholding, cache or session reduction, fast refusal, old-transport release, explicit stop, rekey, and cancellation interactions without unbounded side queues. 5. Privacy-safe metrics, state diagrams, invariant tests, and evidence fields are traceable to the packet, SSH, DNS, relay, reconnect, and tuning owners.
