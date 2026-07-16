# Implement validated compatible and fail-closed network settings

## Description
Extend the pure Network Extension settings builder with explicit compatible and platform-scoped fail-closed modes, preserving dual-stack defaults, exact endpoint exclusion, tunnel-owned DNS, accepted MTU, capability checks, and privacy-safe normalized summaries.

## Scope
In scope: route-mode enum and version; compatible settings; includeAllNetworks where supported; platform and OS capability abstraction; documented system-exception flags for downstream disclosure; IPv4 and IPv6 included routes; exact authenticated endpoint exclusion; DNS match behavior; MTU; collision and broad-route validation; equality and golden summaries; tests. Out of scope: applying settings, physical behavior claims from pure tests, arbitrary user exclusions, per-app routing, endpoint resolution, ordinary physical DNS, route reconnect orchestration, or absolute kill-switch guarantees.

## Acceptance Criteria
1. Compatible mode produces approved dual-stack default routes and only exact required exclusions, while fail-closed additionally enables includeAllNetworks only through a verified supported platform branch. 2. Both modes require a current authenticated /32 or /128 SSH endpoint exclusion, tunnel-owned DNS, accepted MTU, valid virtual addresses, and no caller-supplied broad bypass. 3. Unsupported fail-closed capability, missing family, broad or colliding exclusion, invalid DNS, invalid MTU, and contradictory settings fail before an Apple settings object is returned. 4. Normalized summaries expose mode, families, prefixes, route and exclusion counts, DNS ownership, include-all support, and exception-category flags without full addresses. 5. Unit, compile, and golden tests cover iOS and macOS branches, OS capability changes, both families and modes, collision, unsupported API, stable normalization, and secret rejection.
