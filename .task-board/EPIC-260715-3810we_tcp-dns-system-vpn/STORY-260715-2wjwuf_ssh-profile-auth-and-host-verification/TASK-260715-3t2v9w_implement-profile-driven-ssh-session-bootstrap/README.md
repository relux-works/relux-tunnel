# Implement profile-driven authenticated SSH session bootstrap

## Description
Implement the M1 bootstrap service that consumes one validated profile, resolves candidate SSH endpoints on the physical path before tunnel routes exist, opens the M0-selected in-process SSH transport, enforces host identity, retrieves credentials only after host acceptance, performs public-key authentication, and returns the actual connected endpoint plus one owned session.

## Scope
In scope: physical-path bootstrap resolution before network settings, ordered endpoint attempts, connection timeout and cancellation, host evidence callback, deferred credential resolution, Ed25519 and M0-approved fallback key type, actual remote IPv4 or IPv6 endpoint evidence, selected algorithms and session metrics, keepalive baseline, and one session lifetime. Out of scope: installing routes, reconnect after path change, NAT64 transition policy, lane pools, relay exec, direct-tcpip flows, profile UI, password auth, ProxyJump, and re-running the engine matrix.

## Acceptance Criteria
1. No default tunnel route is installed by this service and endpoint resolution plus connection complete on the pre-tunnel physical path. 2. Host policy accepts before credential retrieval or authentication, and all failure orderings are observable in tests. 3. Successful bootstrap returns one selected-engine session bound to the canonical profile, verified host identity, credential generation, and actual connected IPv4 or IPv6 endpoint. 4. Ed25519 and the approved fallback key type authenticate against supported fixtures, while rejection, timeout, cancellation, and host change close sockets and session state. 5. The service exposes only privacy-safe algorithm, timing, endpoint-family, and error metrics and never retains secret material after authentication setup.
