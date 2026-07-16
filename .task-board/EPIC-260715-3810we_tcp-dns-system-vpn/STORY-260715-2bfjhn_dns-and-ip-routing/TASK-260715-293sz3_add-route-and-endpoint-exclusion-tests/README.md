# Add dual-stack route and SSH endpoint exclusion tests

## Description
Build pure settings and provider-adapter tests for virtual address collision handling, IPv4 and IPv6 default routes, actual SSH endpoint host exclusions, DNS ownership, MTU, Apple automatic tunnel-server behavior instrumentation, ordering, and rollback on both supported platforms.

## Scope
In scope: settings value golden tests, v4 and v6 endpoints, candidate versus actual endpoint changes, host prefix lengths, no broad exclusions, virtual address collisions, absent family, accepted M0 MTU, tunnel DNS and match domains, platform capability branches, application callback success or failure, packet-read ordering, and diagnostics summaries. Out of scope: live path migration, NAT64 transition, captive portals, fail-closed mode, physical leak capture owned separately, reconnect, general UDP, and private Apple APIs.

## Acceptance Criteria
1. Golden cases produce both default families, exact host exclusions, tunnel-owned DNS, and accepted MTU with no unrelated or broad excluded route. 2. Invalid or conflicting addresses, wrong endpoint family, broad prefixes, missing DNS, unsupported MTU, stale endpoint evidence, and settings callback failure are rejected or rolled back deterministically. 3. Instrumented adapter tests prove SSH actual endpoint capture precedes settings and settings success precedes packet reads and usable capability. 4. Separate iOS and macOS cases record whether Apple automatic tunnel-server exclusion is relied on, supplemented, or rejected according to the approved contract. 5. Tests use only public Network Extension and Darwin abstractions and privacy-safe summaries and fail on private utun discovery or full-address logging.
