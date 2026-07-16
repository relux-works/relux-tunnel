# Implement the compatible-mode Network Extension settings builder

## Description
Implement a pure validated builder for iOS and macOS NEPacketTunnelNetworkSettings using the approved M1 network contract. Produce tunnel remote address metadata, virtual IPv4 and IPv6 settings, default included routes, narrow SSH endpoint exclusions, accepted MTU, and a tunnel-owned DNS configuration.

## Scope
In scope: value types independent of provider callbacks, NEIPv4Settings, NEIPv6Settings, included and excluded routes, NEDNSSettings addresses and match domains, MTU, platform capability branches with explicit tests, collision validation, deterministic equality or summaries, and no-secret diagnostics. Out of scope: applying settings, resolving endpoints, packet reads, fail-closed properties, includeAllNetworks, excludedRoutes beyond approved endpoint or documented platform need, DNS forwarding implementation, and reconnect updates.

## Acceptance Criteria
1. Valid input produces both IPv4 and IPv6 default included routes, exact virtual addresses and prefixes, only approved narrow exclusions, tunnel DNS addresses, match-all DNS behavior, and the M0-accepted MTU. 2. Missing family, conflicting virtual address, non-host endpoint exclusion, invalid MTU, resolver-policy mismatch, unsupported platform field, and broad exclusion fail before an Apple settings object is returned. 3. The builder cannot accept raw credentials, profile secrets, destination routes, or arbitrary caller-supplied broad exclusions. 4. Golden summaries for iOS and macOS expose families, prefixes, route counts, DNS ownership, and MTU without logging full local or SSH addresses. 5. Unit and generated-target compile tests cover both families, platform branches, collision cases, and stable output across equivalent normalized inputs.
