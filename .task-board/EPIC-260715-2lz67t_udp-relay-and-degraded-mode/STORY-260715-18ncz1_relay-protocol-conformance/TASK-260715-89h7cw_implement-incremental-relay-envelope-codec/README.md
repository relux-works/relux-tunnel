# Implement the incremental relay envelope codec

## Description
Implement the outer frame encoder and bounded incremental decoder used on stdin and stdout streams, preserving multiple frames per read, partial frames across reads, message direction, and deterministic terminal framing errors.

## Scope
In scope: four-byte length prefix; type, flags, associationID, and payload; network byte order; minimum length 6; negotiated maximum; partial prefix and body accumulation; coalesced frames; bounded scratch storage; output write slices; EOF; cancellation; message metadata validation hook; aggregate byte and frame metrics. Out of scope: interpreting HEV payload bytes, handshake exchange, association lifetime, socket I/O, SSH channel scheduling, queue policy outside the codec, and protocol version negotiation.

## Acceptance Criteria
1. The encoder emits frameLength from type through payload and exact network-byte-order fields for every legal payload size without integer truncation or overflow. 2. The decoder returns zero or more ordered frames for every incremental or coalesced input pattern and retains at most the negotiated frame plus constant prefix state. 3. Length below 6, above the negotiated cap, arithmetic overflow, reserved flags, invalid direction, unexpected EOF, and malformed state produce the specified terminal session error without allocating from attacker-declared size first. 4. Empty input, one-byte chunks, every prefix or body split, multiple frames, cancellation, and reuse after reset are deterministic in both language implementations. 5. Unit, property, and allocation instrumentation reconcile input bytes, output frames, retained bytes, and failure counts and never log payload or destination content.
