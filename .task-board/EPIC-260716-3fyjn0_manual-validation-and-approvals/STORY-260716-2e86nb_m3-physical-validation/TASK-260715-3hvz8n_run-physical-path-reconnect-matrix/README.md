# Run the physical Wi-Fi, cellular, loss, and endpoint reconnect matrix

## Description
Execute the reconnect acceptance matrix on named physical iPhone and Mac devices across Wi-Fi and cellular transitions where supported, transport and lane failures, server-address changes, and repeated stops, with route, DNS, capability, memory, and cleanup evidence.

## Scope
In scope: iPhone Wi-Fi to cellular and cellular to Wi-Fi; Mac supported interface changes; path unavailable and recovery; lane-A and server loss; cached endpoint success and failure; server address change; IPv4 and IPv6 native rows; full and degraded restoration; compatible mode baseline; controlled DNS and traffic sentinels; authorized captures; outage, retry, route, memory, queue, and cleanup metrics. Out of scope: final NAT64, sleep or captive rows, fail-closed route acceptance owned separately, public-user traffic, host-key auto-replacement, or waiver of unavailable platform rows.

## Acceptance Criteria
1. A TASK-ID-scoped matrix records device, OS, Xcode, revisions, interface transition, endpoint family and change, route mode, capability start and end, traffic, timings, retries, routes, counters, memory, captures, and raw artifact references. 2. Each supported path transition reconnects through the selected physical interface, captures the actual endpoint, installs only the current exact exclusion, and restores truthful full or degraded capability without deadlock. 3. Access captures and sentinels show no ordinary DNS or application fallback and no recursive SSH route during loss, retry, settings replacement, reasserting, degraded, failure, or stop. 4. Host-key and authentication terminal fixtures stop retry, while transient loss follows bounded backoff and user stop cancels promptly. 5. Repeated trials keep reconnect overlap within the reservation and return routes, sessions, lanes, channels, associations, tasks, timers, sockets, and descriptors to baseline.
