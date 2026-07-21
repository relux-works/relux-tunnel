# Rework 01 — preserve typed relay UDP error disposition

Consume `TASK-260715-1loqwb_review-verdict-01.md` as authoritative rework evidence. Do not broaden scope or revisit already-green framing/admission work.

Required behavior:

1. Carry the concrete `RelayRemoteAssociationError` (or generated finite UDP error code with an equally explicit typed mapping) from `RelaySession` into the adapter callback. Do not collapse finite peer errors into an untyped terminal event.
2. `queueSaturated (0x0006)` is a nonterminal edge-triggered pressure/drop signal. Count it without closing HEV, sending `CLOSE_ASSOCIATION`, changing the registry handle, or preventing later bidirectional datagrams on the same ID.
3. `datagramTooLarge (0x0005)` received without a peer close is nonterminal because it may reflect a lower relay-local cap. Count/drop it and keep the association. If the peer subsequently sends `CLOSE_ASSOCIATION`, that independent lifecycle message retires exactly once.
4. Preserve association-local terminal behavior for the remaining finite and unknown errors according to the accepted relay-v1 contract. A terminal error followed/raced by close must not double-close the descriptor, double-release registry state, or emit duplicate close.
5. Add deterministic fake-relay regressions for both nonterminal codes proving the exact same association ID accepts a later outbound request and inbound response, plus terminal error/close orderings proving exactly-once cleanup and post-ack baseline. Assert privacy-safe aggregate metrics without raw error bytes/destinations.
6. Re-run focused tests repeatedly, focused TSan, full Swift tests/build, relay protocol check, strict format/diff, core boundaries, privacy/public-proxy scans, and board validation. Update the task-scoped result evidence (or add a task-scoped rework result), record the finding in the logbook, and hand off at `to-review`.

Do not change the wire schema, invent a new final policy value, or implement SSH pumping/resource-policy work.
