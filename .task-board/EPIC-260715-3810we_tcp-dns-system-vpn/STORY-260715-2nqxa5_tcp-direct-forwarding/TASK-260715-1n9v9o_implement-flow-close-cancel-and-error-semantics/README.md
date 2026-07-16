# Implement TCP flow close, half-close, cancellation, and error semantics

## Description
Implement the per-flow lifecycle around the SOCKS endpoint, direct-tcpip channel, and two byte pumps. Translate local EOF, remote EOF, half-close, reset, channel rejection, timeout, SSH-session loss, provider stop, and late callbacks into deterministic actions and one cleanup path.

## Scope
In scope: flow state machine, independent send and receive closure, shutdownWrite where supported, drain policy, reset and rejection mapping, handshake and idle or open deadlines defined by contract, provider cancellation, session-failure fan-out, once-only unregister, descriptor and channel close, and reason metrics. Out of scope: automatic reconnect, replaying or migrating live flows, application retries, lane failure recovery, stream buffer implementation, and routing changes.

## Acceptance Criteria
1. Local EOF closes the SSH send side without discarding permitted remote bytes, and remote EOF closes the local send side while respecting remaining local input according to the contract. 2. Reset, rejection, timeout, provider stop, and SSH-session loss have distinct deterministic outcomes and cannot hang on a half-closed peer. 3. Exactly one terminal reason wins, unregisters the flow, cancels both pumps, closes channel and socket resources, and releases admission capacity. 4. Late open, read, write, EOF, and cancellation callbacks after terminal state are harmless and cannot reopen or double-free resources. 5. State-table tests cover every pairwise close race and repeated runs return tasks, buffers, sockets, channels, and registry entries to baseline.
