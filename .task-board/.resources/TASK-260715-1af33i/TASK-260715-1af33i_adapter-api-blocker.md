# TASK-260715-1af33i — ReluxNIOSSH adapter API blocker (round 2)

## Stop-the-line result

The reviewer-accepted neutral contract and the reviewer-accepted 20-file
ReluxNIOSSH fork delta still do not compose for two mandatory adapter
requirements. Product-code work stopped before adding an adapter-owned receive
buffer that lies about protocol credit, downcasting an injected connection,
or pumping a fake byte connection through a local socketpair.

No product source, package manifest, provider composition, or test source was
changed in this run.

## Gap 1: receive credit is returned before `SSHByteChannel.read` consumes it

The neutral contract requires receive credit to become eligible for return only
after `read(maximumBytes:)` delivers those bytes to its caller. It also requires
`receiveWindow()` to distinguish buffered unread bytes from delivered credit,
and requires `maximumBufferedReadBytes` to remain a hard bound.

The fork currently accounts delivery at the NIO child-pipeline boundary:

- `SSHChildChannel.handleInboundChannelData` and
  `handleInboundChannelExtendedData` debit the receive window and append the
  whole SSH frame to `pendingReads`
  (`Dependencies/ReluxNIOSSH/Sources/NIOSSH/Child Channels/SSHChildChannel.swift:859-873`).
- `deliverSingleRead` fires the whole `SSHChannelData` into the adapter pipeline,
  immediately calls `windowManager.unbufferBytes(data.data.readableBytes)`, and
  may emit WINDOW_ADJUST for the whole frame
  (`SSHChildChannel.swift:684-707`).
- `ChildChannelWindowManager.unbufferBytes` moves that whole count into
  delivered credit and returns it when the threshold is reached
  (`ChildChannelWindowManager.swift:89-121`).
- The local maximum packet size remains a hard-coded `1 << 24`
  (`SSHChildChannel.swift:506-517`), and no public option limits a delivered
  frame to the pending API read's `maximumBytes`.

Consequently, if the peer supplies a 16 KiB frame while the caller requests
`read(maximumBytes: 1_024)`, an adapter handler must retain a 15 KiB suffix, but
the fork has already made all 16 KiB eligible for WINDOW_ADJUST. The common
snapshot would either under-report adapter-buffered bytes or report a credit
state inconsistent with the wire. Disabling `autoRead` does not fix this: it
delays delivery of a frame but cannot split the frame before the fork returns
credit.

The same design cannot enforce a caller policy where
`maximumBufferedReadBytes < initialReceiveWindowBytes`: the fork may hold up to
the advertised receive window in `pendingReads`, and the adapter has no intake
or credit hook below that buffer.

Evidence command:

```text
swift test --filter windowAdjustmentEvent
```

passed one Swift Testing case. That existing fork test deliberately feeds a
16 KiB frame and observes a 16 KiB adjustment immediately after one pipeline
read, confirming the current pipeline-delivery semantic rather than the
required API-consumption semantic.

## Gap 2: the injected TCP byte seam cannot host NIOSSH

`SSHTransportDependencies.connector` returns an `SSHTCPConnection` exposing
only candidate-neutral readiness, `readSome`, `writeSome`, and `close`
(`Sources/ReluxTunnelCore/SSHContracts.swift:148-164`). The contract requires
this seam to remain replaceable for readiness and cancellation tests.

`NIOSSHHandler` is only a NIO `ChannelDuplexHandler`; its public initializer
must be installed in a NIO `Channel` pipeline
(`Dependencies/ReluxNIOSSH/Sources/NIOSSH/NIOSSHHandler.swift:15-112`). The
upstream client uses `NIOPosix.ClientBootstrap` to create the socket directly
(`Dependencies/ReluxNIOSSH/Sources/NIOSSHClient/main.swift:43-76`). NIO can take
ownership of an existing connected socket with
`ClientBootstrap.withConnectedSocket`, but the accepted neutral
`SSHTCPConnection` intentionally exposes no transferable socket descriptor or
NIO channel.

An adapter-private downcast to its own connection wrapper would make injected
fake connectors unusable and violate E-INJECTION. Opening a second NIO socket
would ignore the injected connector. A local socketpair plus two byte pumps
would add an artificial transport, duplicate buffering and cancellation, and
hide the architectural mismatch; it is a forced fit, not a conforming
implementation.

## Failed assumptions and rejected workarounds

- `autoRead = false` cannot defer credit for a prefix of one SSH frame.
- Adapter-side suffix buffering cannot reconcile the fork snapshot with wire
  credit after the fork has adjusted the entire frame.
- Reducing the advertised initial window to `maximumBufferedReadBytes` changes
  the caller's required initial wire window and still does not enforce arbitrary
  `maximumBytes` reads.
- A candidate-specific downcast of `SSHTCPConnection` defeats type-erased fake
  injection.
- A socketpair pump or a second direct NIO connection adds compensating I/O and
  bypasses the accepted network ownership model.
- Tests that use only `NIOEmbedded` would avoid both production constraints and
  therefore cannot establish contract conformance.

## Viable options

1. **Recommended: close both seams explicitly before resuming the adapter.**
   Revise the neutral TCP dependency with an accepted candidate-neutral
   connected-socket ownership/lease or engine-bootstrap capability that remains
   fakeable, and extend the fork with explicit consumer-driven receive-credit
   return plus a configurable local maximum packet/intake bound. Add a fork test
   where a 16 KiB SSH frame is consumed through 1 KiB API-sized prefixes and
   only consumed prefixes earn credit.
2. Extend ReluxNIOSSH with a public byte-oriented transport driver over the
   existing `SSHTCPConnection` semantics, including consumer-driven receive
   credit. This preserves the current core seam but is a materially larger fork
   delta and duplicates more NIO transport machinery.
3. Weaken the neutral contract's E-WINDOW/E-INJECTION requirements. This is not
   recommended: it would reopen the accepted contract and make the candidate
   comparison non-equivalent.

## Recommendation and exact input needed

Architecture owners should approve option 1 and assign atomic owners for:

1. the candidate-neutral connected-socket/engine-bootstrap injection shape; and
2. ReluxNIOSSH consumer-driven receive-credit and maximum-packet/intake hooks.

Resume TASK-260715-1af33i only after both APIs are reviewer-accepted with
deterministic tests, or after architecture owners explicitly revise the common
contract. The adapter can then implement host verification, authentication,
channels, rekey, keepalive, cancellation, metrics, harness registration, and
Apple builds without compensating hacks.

## Verification performed

- Read and traced the accepted neutral contract and all relevant fork paths.
- Re-ran the focused existing fork window test: 1 test passed.
- No adapter tests, root build, harness smoke, or Apple matrix was run because
  there is no valid adapter implementation to build yet.
