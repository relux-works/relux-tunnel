# TASK-260715-1jvgcn logbook

## 2026-07-20

- Kept schema/generated metadata authoritative for message direction, association ID, and fixed payload widths; handwritten tables add only response and close effects.
- Chose one acknowledgement policy: acknowledge an active peer-initiated association/session close only when the local close was not already sent. Duplicate, crossed, and late closes never generate another acknowledgement.
- Structural HEV failures remain association-scoped. The relay orders a generated UDP error before association close; a lowered local payload cap emits generated `datagramTooLarge` and drops without closing.
- Made PONG and UDP_ERROR response-only in the generic send API. PONG is created only by bounded eight-byte PING echo; UDP_ERROR is created only through a generated finite-code API with no diagnostic metadata parameter.
- Added a frame-boundary query to each incremental decoder so exact-boundary post-handshake `RLXR` maps to finite `postHandshakeHello` without handshake lookahead or a transport barrier.
- Cleanup callbacks carry the session generation and are guarded independently for every association lifecycle and for the whole generation. Stale generations and late callbacks are counted but cannot clean up current state.
- The Go module scaffold is not present by design; used the repository-owned smoke gate rather than creating a competing module or changing the frozen ownership boundary.
- Rework made the post-handshake magic detector retain at most the partial four-byte `RLXR` candidate outside the decoder; ordinary frame prefixes bypass copying and every segmentation reaches the same finite reason.
- Outbound datagram validation now precedes association activation, preventing invalid local records from creating lifecycle state or reaching the wire.
- Reserved special error codes no longer pass through the generic disposition API. Queue saturation owns a stateful episode edge with injected half-cap recovery, while idle expiry owns the mandatory finite-error, cleanup/retirement, then close order.
- Live-association abrupt termination tests deliberately drive both peers through identical traffic and late/stale callbacks, allowing the complete session metrics structs and both cleanup recorders to reconcile exactly.
- Review round 2 found that inbound datagram handling still activated missing IDs before HEV validation, client inbound accepted relay-chosen IDs, relay outbound created missing IDs, and neither session map used injected association limits.
- Round 2 rework split lifecycle handling into payload validation, client-owned admission, and active-association lookup. Invalid first frames now produce bounded error/close policy output without creating cleanup-owned state.
- Association credit counts every active or half-closed lifecycle record. Only fully retired records, proven by both close directions, can be reused or pruned before fresh admission. This bounds unique-ID state growth while preserving ordered reuse.
- Unsolicited and closed relay replies are never delivered. Relay-local reply/error APIs reject unknown or closed IDs, and the client uses a no-state bounded close response for unsolicited valid frames.
