# Resolve protocol v1 resource-limit exchange

## Description
Produce the binding compatibility decision for association count, queued bytes, datagram size, and idle timeout because protocol v1 currently advertises only features and maxFrame while the resource contract calls the broader set negotiated or capped.

## Scope
In scope: trace the hello and message table; distinguish negotiation from unilateral local caps; compare fixed v1 constants, a feature-gated post-hello limits message, hello extension, and new protocol version; backward compatibility; minimum and maximum safety; client and relay ownership; diagnostics; vector and migration impact; accountable architecture approval. Out of scope: implementing codecs or UDP queues, changing requirements silently, guessing peer limits, weakening hard caps, protocol v2 beyond the minimal option analysis, and selecting based only on implementation convenience.

## Acceptance Criteria
1. A TASK-ID-scoped decision quotes the conflicting v1 fields and resource requirement and separates facts, assumptions, and compatibility consequences. 2. It compares fixed local caps, feature-gated v1 exchange, incompatible hello change, and new-version options for old-peer behavior, safety, complexity, vectors, and rollout. 3. The selected contract specifies exact wire fields or fixed values, byte order, defaults, hard ceilings, invalid-value behavior, diagnostics, feature or version gating, and which peer may lower each limit. 4. The decision proves that an existing v1 peer never misparses extended bytes and that neither peer allocates or admits work above its local hard cap. 5. Accountable architecture approval is recorded and downstream schema, handshake, session, vector, UDP limit, capability, and documentation tasks are updated by concrete ID; absent approval the task remains the sole explicit blocker.
