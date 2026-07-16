# Implement the relay UDP association and socket registry

## Description
Implement the rootless relay mapping from client association IDs to bounded UDP socket state, family-specific descriptors, activity and idle timers, close state, and session-wide cleanup without binding a public listener.

## Scope
In scope: nonzero associationID validation; configured maximum; lazy IPv4 and IPv6 socket creation per association as required; unconnected or explicitly documented connected-socket policy; rootless ephemeral local ports; nonblocking descriptors; activity and idle timers; close and expiry; session generation; descriptor admission; owner task; cancellation; aggregate counts. Out of scope: datagram send and receive logic, domain resolution, client ID allocation, public inbound sockets, privileged ports, persistent daemon state, firewall changes, and destination logging.

## Acceptance Criteria
1. A valid new association creates at most the documented bounded family-specific socket state and duplicate or conflicting IDs follow the protocol state contract without replacing active ownership. 2. Every socket is nonblocking, rootless, session-owned, unavailable as a public service, and closed once on association close, expiry, session close, process termination, or cancellation. 3. Maximum association, socket, timer, and pending-close ceilings reject excess work before descriptor creation and expose finite aggregate reason counters. 4. Idle activity and expiry use an injected monotonic clock and races with send, reply, remote close, local close, and session shutdown cannot leak or reuse live state. 5. Fake-clock and controlled-socket tests cover IPv4 only, IPv6 only, dual family, duplicate IDs, exhaustion, expiry, crossed close, session loss, descriptor failure, and repeated return to baseline.
