# TASK-260715-1juybj — accepted M0 capability trace

This task-scoped index records the accepted capabilities consumed by the
private SOCKS-to-`direct-tcpip` contract. It is a reference map, not a new pin or
tuning decision.

## HEV/lwIP pin and upstream boundary

Accepted source: `TASK-260715-uopycx` — **Pin and audit the HEV and lwIP
baseline**, reviewer accepted.

| Capability | Accepted evidence |
| --- | --- |
| Pinned graph | `hev-socks5-tunnel` `ad7600497931205105b08367bd1b450048157e40`; core `c234519072ff5b928b90b304da9a666bcb440455`; task-system `b1afa0e21fb4ed5a69560e78e54baf0efdebe171`; lwIP `2a11c14c7a32887af25a034e82ef18b0b12076ac`; yaml `efa36117a8646d26d12b58e05bac472d7854a70d` |
| Upstream SOCKS endpoint | `socks5.address` plus TCP port. Accepted audit records closed issue #297: Unix-domain upstream listener is not supported, and open issue #301: no owner-admission callback. Therefore loopback TCP admission remains adapter owned. |
| Authentication client | Pinned `hev-socks5-client.c` selects RFC 1929 method `02` whenever both configured username and password exist; it writes one-byte username/password lengths. |
| TCP request | Pinned protocol defines `CONNECT=01`; client emits `[05 01 00 ...]`. Address types are IPv4 `01`, domain `03`, and IPv6 `04`. |
| Reply compatibility | Pinned client consumes a four-byte response prefix and then only IPv4 or IPv6 bound-address forms. This is why the contract fixes the canonical ten-byte IPv4 `0.0.0.0:0` reply. |
| Remote resolution | A domain address remains a domain in the SOCKS request; the adapter contract passes it as the RFC 4254 destination string and performs no local destination lookup. |
| UDP separation | Pinned private UDP-in-TCP command is `05`. The TCP adapter accepts only `CONNECT=01`; UDP/relay framing remains separately owned. |

Primary task-scoped inputs:

- `.task-board/.resources/TASK-260715-uopycx/TASK-260715-uopycx_pinned-baseline-audit.md`
- `.task-board/.resources/TASK-260715-uopycx/TASK-260715-uopycx_dependency-manifest.json`
- retained pinned source under `.temp/TASK-260715-uopycx/hev-socks5-tunnel`

## Accepted shared Apple implementation

Accepted source: `TASK-260715-1vv52g` — **Integrate pinned HEV and lwIP behind
the native adapter**, including accepted rework review.

| Capability | Accepted evidence |
| --- | --- |
| Private listener | `HEVLoopbackSOCKSBoundary` binds `AF_INET/SOCK_STREAM` to `127.0.0.1:0`; no wildcard/interface listener exists. |
| Generation capability | `HEVLoopbackSOCKSBoundaryFactory` creates fresh RFC 1929 credentials for each boundary. Only authenticated channels reach `HEVSOCKSConnectionAdapter`, at the first request byte. |
| Bounded pre-admission | Caller injects a positive maximum pending count and `authenticationTimeoutMilliseconds`; pending descriptors are tracked in a bounded set. Current code applies that duration only as `SO_RCVTIMEO`, a per-receive inactivity bound that can restart with progress. It is not an absolute accept-to-authentication deadline, and authentication reply sends have no deadline. |
| Lifecycle | Stop cancels the listener, shuts pending descriptors, awaits listener cancellation and authentication tasks, and is idempotent. Accepted rework moved listener close to its cancel handler and covered stop ordering. |
| Platform shape | One `ReluxTunnelNativeAdapter` target is compiled/linked into iOS device, iOS Simulator, macOS adapter/provider, shared consumer, and macOS harness schemes. The boundary source has no platform-conditional behavior. |
| Negative ingress | `HEVIntegrationTests.externalIngressRejected` and the real-HEV `realHEVUDPInTCPAndInternalIngress` test prove `[05 01 00] -> [05 ff]` and zero adapter handoffs; reviewer-rerun native matrix and tests passed. |
| M1 deadline gap | Current tests prove immediate no-auth rejection but do not prove slow-trickle or authentication-reply-stall eviction. `TASK-260715-b6uruh` must introduce one caller-injected monotonic absolute deadline from accept through the final authentication reply and validate slow trickle, wrong credentials, reply stall, cancellation, stale generation, slot release, and descriptor cleanup on both platform targets. |

Primary task-scoped inputs:

- `.task-board/.resources/TASK-260715-1vv52g/TASK-260715-1vv52g_results.md`
- `.task-board/.resources/TASK-260715-1vv52g/TASK-260715-1vv52g_rework-01-review-verdict.md`
- `Sources/ReluxTunnelNativeAdapter/HEVSOCKSBoundary.swift` SHA-256
  `8742e306c9625ab56e6745b956e853c96246c50eb56dd7c530f63962bae0cc2a`

## M0 memory inputs consumed as measurements

Accepted ADR-020 evidence explicitly exercises:

- MTU 1,500 bytes;
- requested/effective HEV task stack 24,576 bytes;
- HEV TCP buffer 4,096 bytes;
- `udp-copy-buffer-nums=2`, which keeps the pinned stack minimum at 24,576;
- maximum HEV sessions 1,200.

Every value remains caller injected and must be remeasured. In particular,
`max-session-count` is not treated as a sufficient adapter memory proof or an
instantaneous allocation cap. The contract requires hard adapter reservations,
includes SSH queues/read buffers and measured per-flow/task overhead, and fits
their aggregate under the provisional 25–30 MiB full-extension envelope before
production ceilings are accepted.

Primary task-scoped inputs:

- `.task-board/.resources/TASK-260715-1vv52g/TASK-260715-1vv52g_approved-decision.md`
- `.task-board/.resources/TASK-260715-1vv52g/TASK-260715-1vv52g_effective-config-probe.log`
- `.spec/packet-plane.md`

## Runtime and SSH seams

- Accepted `TASK-260715-30zng6_runtime-contract.md` makes the generation packet
  plane the sole owner of the private listener/credential and the TCP consumer
  the owner of accepted flows, bounded pumps, and channel lifecycle.
- The accepted SSH task is `TASK-260720-100wu6`, not the mistyped
  `TASK-260715-100wu6` in this task's input. `SSHTransport.openDirectTCPIP`,
  `SSHChannelPolicy`, and `SSHByteChannel` are the only consumed engine-neutral
  public seam. `SSHContracts.swift` SHA-256 is
  `95dec4422724ddc93c201fd5dafc7af562a20a30e50186c0977f8705fb03542a`.
- Exact SSH-engine observability and selection remain outside this task. The M1
  assignment seam returns the accepted baseline transport/policy once; M3 may
  replace selection logic but cannot migrate an open flow.
