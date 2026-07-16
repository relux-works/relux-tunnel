# Document protocol compatibility, limits, and change gates

## Description
Publish the developer protocol contract after conformance passes, including byte layouts, state behavior, negotiated and hard limits, privacy constraints, generator ownership, version policy, verification commands, and consumer migration rules.

## Scope
In scope: v1 hello and envelope tables; HEV payload layout; message direction and failure scope; association identity contract; feature negotiation; hard and negotiated limits; error and close behavior; diagnostics redaction; schema and vector workflow; backward-compatible feature criteria; new-version criteria; CI and local commands; bootstrap, UDP, and build handoffs. Out of scope: user help, remote installation instructions, UDP implementation internals, final supply-chain policy, protocol v2 specification, and changing accepted behavior while documenting it.

## Acceptance Criteria
1. One TASK-ID-scoped document reproduces every field width, byte order, length definition, message value, direction, address type, and close or error consequence without contradicting generated artifacts. 2. Tables distinguish local hard caps, peer-advertised values, negotiated results, saturation behavior, and which violations close an association or session. 3. A compatibility decision tree states exactly when an optional feature bit is safe, when peers must reject, and when a new protocol version and parallel vectors are mandatory. 4. Regeneration, conformance, fuzz, CI, and release-gate commands are runnable and name their expected artifacts and failure outputs. 5. Security review confirms documentation and examples contain no real destinations, domains, payloads, credentials, or command stdin and downstream tasks link this artifact.
