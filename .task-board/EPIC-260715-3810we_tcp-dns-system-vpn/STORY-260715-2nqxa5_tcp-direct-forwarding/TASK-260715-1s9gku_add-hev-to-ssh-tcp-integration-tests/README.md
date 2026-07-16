# Add end-to-end HEV-to-SSH TCP integration tests

## Description
Exercise the integrated M0 packet bridge and HEV stack through the private SOCKS adapter and M0-selected SSH transport to controlled destination servers. Verify ordinary application-like TCP from synthetic IPv4 and IPv6 packets becomes independent direct-tcpip connections with correct bytes and closure.

## Scope
In scope: harness packet injection, HEV TCP termination, private SOCKS negotiation, selected SSH session, IPv4, IPv6, domain targets where HEV supplies them, short requests, bidirectional streams, upload, download, half-close, early close, reset, channel rejection, concurrent flows, diagnostics, and cleanup. Out of scope: system routes, physical Network Extension, DNS leak behavior, engine comparison, 5 GiB rekey matrix owned separately, lanes, UDP, and reconnect.

## Acceptance Criteria
1. Controlled packets establish successful IPv4 and IPv6 application-visible TCP sessions through HEV and one distinct direct-tcpip channel per flow. 2. Request, response, upload, download, and mixed bidirectional hashes match across the complete packet-to-channel path. 3. Half-close, server close, client close, reset, channel rejection, and SSH-session failure produce bounded application-visible outcomes and no hung flow. 4. A mixed nominal concurrency run has no ordinary drops under unsaturated configured limits and diagnostics reconcile packets, flows, channels, and bytes. 5. Repeated scenarios return bridge, HEV session, SOCKS connection, channel, buffer, task, socket, and descriptor counts to baseline.
