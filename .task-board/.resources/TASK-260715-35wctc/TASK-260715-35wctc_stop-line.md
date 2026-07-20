# TASK-260715-35wctc stop-the-line result

## Outcome

Added `Tests/ReluxTunnelNativeAdapterTests/HEVBridgeIntegrationTests.swift` and wired the native-adapter test target to `ReluxTunnelMacOSAdapter`.

The deterministic harness feeds raw IPv4/IPv6 packets through the macOS PacketFlow test seam, `PacketFlowBridge`, a real Darwin socketpair, the pinned unmodified HEV/lwIP XCFramework, and an authenticated loopback SOCKS fixture. The test matrix includes concurrent IPv4/IPv6 TCP handshakes, bidirectional small/bulk payloads, half-close, reset, UDP-in-TCP command/framing, unauthorized internal ingress, stalls/drop accounting, bridge-fault cleanup, ADR-020 gauges, and 100 real lifecycle cycles.

## Passing evidence before the blocker

- `swift build`: passed.
- Existing `HEVIntegrationTests`: 8/8 passed.
- `realHEVUDPInTCPAndInternalIngress`: passed through the real HEV binary.
- `realHEVTCPMatrix`: completed both real TCP flows and all SOCKS/stream lifecycle assertions.

## Blocking regression

`realHEVTCPMatrix` then fails only these completed-run observability assertions:

- `hev_transmitted_packets > 0` (actual 0)
- `hev_received_packets > 0` (actual 0)

Production Swift calls `runtime.statistics()` only after joining HEV. Pinned HEV executes `hev_socks5_tunnel_fini()` before returning and clears all four traffic-stat globals there, so a post-join stats call can only observe zero.

Tracked as `BUG-260720-2p4fln` — Preserve HEV traffic statistics before fini.

## Required resolution

Recommended: retain the completed-run traffic-counter contract and change the runtime seam to snapshot statistics while HEV is still active, without modifying pinned HEV or regressing quit-after-return safety. After that bug lands, rerun the full integration matrix, coverage, strict formatting/lint, and ThreadSanitizer before handing this task to review.
