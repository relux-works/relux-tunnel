# Platform and upstream verification

Date: 2026-07-15

Purpose: record primary-source evidence used by the VPN architecture specs. This
is a point-in-time verification; dependency pins and Apple behavior must be
rechecked during M0 and before release.

## Apple Network Extension

- [`NEPacketTunnelProvider`](https://developer.apple.com/documentation/networkextension/nepackettunnelprovider)
  exposes `packetFlow`, tunnel network settings, routes, DNS, and MTU, and
  describes encapsulating IP packets for a tunnel server. It requires the
  Network Extension entitlement.
- [`NETunnelProviderManager`](https://developer.apple.com/documentation/networkextension/netunnelprovidermanager)
  is the containing app's manager for custom packet-tunnel VPN configurations
  and inherits from `NEVPNManager`.
- [TN3120](https://developer.apple.com/documentation/technotes/tn3120-expected-use-cases-for-network-extension-packet-tunnel-providers)
  identifies a full tunnel to a remote VPN server as expected, but warns against
  claiming traffic in a packet provider and proxying it through another
  interface. Local lwIP TCP termination followed by SSH `direct-tcpip` therefore
  needs explicit entitlement/App Review validation (Gate A0).
- [Routing VPN traffic](https://developer.apple.com/documentation/networkextension/routing-your-vpn-network-traffic)
  documents default included routes, endpoint exclusions, interface scoping,
  `includeAllNetworks`, and its system exclusions. Current documentation says
  DHCP, captive-portal negotiation, certain cellular services, companion-device
  traffic, and VPN-maintenance traffic can remain outside the VPN.
- [`reasserting`](https://developer.apple.com/documentation/networkextension/netunnelprovider/reasserting)
  must be true while a provider re-establishes its server connection.
- [`NWParameters.requiredInterface`](https://developer.apple.com/documentation/network/nwparameters/requiredinterface)
  constrains a connection to a specific interface.
- [`NWPath.remoteEndpoint`](https://developer.apple.com/documentation/network/nwpath/remoteendpoint)
  exposes the effective endpoint used by a connection path.
- [`os_proc_available_memory()`](https://developer.apple.com/documentation/os/os_proc_available_memory)
  returns advisory remaining memory relative to a process limit; Apple says not
  to cache it or use it to maximize consumption.
- [App Review Guideline 5.4](https://developer.apple.com/app-store/review/guidelines/#vpn-apps)
  requires VPN apps to use the VPN APIs, be offered by an organization, disclose
  data use, avoid selling/using/disclosing VPN data, and satisfy regional law.

## SwiftNIO SSH

Inspected upstream commit:
[`8257bc486f448799e94e225c4304d5ee0c19964f`](https://github.com/apple/swift-nio-ssh/tree/8257bc486f448799e94e225c4304d5ee0c19964f).

- [`SSHChannelMultiplexer.swift`](https://github.com/apple/swift-nio-ssh/blob/8257bc486f448799e94e225c4304d5ee0c19964f/Sources/NIOSSH/Child%20Channels/SSHChannelMultiplexer.swift#L204-L214)
  contains a TODO to make window parameters configurable and passes
  `targetWindowSize: 1 << 24` to new child channels.
- [`NIOSSHHandler.swift`](https://github.com/apple/swift-nio-ssh/blob/8257bc486f448799e94e225c4304d5ee0c19964f/Sources/NIOSSH/NIOSSHHandler.swift#L505-L520)
  exposes client rekey only as internal `_rekey()` and describes it as primarily
  test support. Server-initiated protocol state exists, but production
  client-initiated byte/time rekey is not a public API at this revision.

Conclusion: vanilla NIOSSH fails the current per-channel-window and automatic
client-rekey gates. A minimal fork and libssh2 must be measured before selection.

## HEV and lwIP

Inspected `hev-socks5-tunnel` commit:
[`1d334516b4018823f463bf51539402108ddc13bc`](https://github.com/heiher/hev-socks5-tunnel/tree/1d334516b4018823f463bf51539402108ddc13bc).

- The [upstream README](https://github.com/heiher/hev-socks5-tunnel/blob/1d334516b4018823f463bf51539402108ddc13bc/README.md)
  documents iOS/macOS builds, default MTU 8500, `socks5.udp: tcp`, and a low-memory
  example using task stack 24576, TCP buffer 4096, and bounded sessions.
- `hev-socks5-core` at
  [`cbff465b916832455c1cb02f1f9e25a41062054d`](https://github.com/heiher/hev-socks5-core/tree/cbff465b916832455c1cb02f1f9e25a41062054d)
  documents command `0x05` and the UDP-in-TCP frame
  `[MSGLEN][HDRLEN][ATYP][DST.ADDR][DST.PORT][DATA]`.
- `hev-socks5-tunnel`, `hev-socks5-core`, and `hev-task-system` contain MIT
  licenses at the inspected revisions. The bundled lwIP license is BSD-style and
  requires preservation in binary-distribution materials.

Conclusion: the dependency set is compatible with the planned distribution,
subject to shipping all notices and re-auditing the exact locked revisions.
