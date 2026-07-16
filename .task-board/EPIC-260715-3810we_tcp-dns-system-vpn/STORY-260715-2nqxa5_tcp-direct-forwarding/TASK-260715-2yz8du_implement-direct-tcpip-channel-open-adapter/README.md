# Implement direct-tcpip channel opening for accepted CONNECT requests

## Description
Implement the adapter step that turns one validated SOCKS CONNECT request into one bounded openDirectTCPIP call on the authenticated baseline SSH session, maps SSH open outcomes to SOCKS replies, and transfers channel ownership to the flow only after both sides are ready.

## Scope
In scope: destination endpoint conversion, domain forwarding for exit-side resolution, originator endpoint policy, channel-open timeout and cancellation, initial M1 channel policy from M0 ranges, session-health rejection, SOCKS success and failure mapping, race-safe ownership, and open metrics. Out of scope: stream pumping, lane selection, retries on another session, flow migration, DNS stub behavior, engine-specific APIs outside the adapter, and opening exec or UDP channels.

## Acceptance Criteria
1. IPv4, IPv6, and domain destinations map to the selected SSH adapter without local destination resolution unless the approved contract explicitly requires it. 2. One accepted CONNECT triggers at most one channel-open attempt and no retry can duplicate a remote destination connection. 3. Success is sent only after the channel is open and owned, while prohibited, unreachable, rejected, timed out, cancelled, closed-session, and resource-limit outcomes map to documented SOCKS replies. 4. Cancellation before or during open closes any late channel and cannot transfer ownership to a stopped flow. 5. Fake and real selected-adapter tests verify destination and originator values, window policy input, reply ordering, metrics, and no channel leak.
