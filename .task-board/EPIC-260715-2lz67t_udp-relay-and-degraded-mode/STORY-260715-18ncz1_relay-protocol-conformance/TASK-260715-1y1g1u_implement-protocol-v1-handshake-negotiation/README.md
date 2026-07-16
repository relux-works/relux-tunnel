# Implement protocol v1 handshake and limit negotiation

## Description
Implement the fixed client and server hello exchange on both sides, including exact byte layout, version and status handling, feature intersection, maximum-frame caps, build-ready typed results, timeout, and deterministic close on failure.

## Scope
In scope: RLXR magic; client version, flags, and maxFrame; server version, status, features, and maxFrame; exact network-byte-order lengths; incremental input; handshake deadline; supported-feature intersection; configured hard caps and minimums; unsupported version; nonzero status; unreasonable limits; duplicate hello; typed diagnostics without remote-controlled text. Out of scope: envelope messages after hello, process launch, build identity transport beyond the approved field or feature contract, retry policy, UDP sockets, and downgrade to another framing format.

## Acceptance Criteria
1. Client and server emit and accept only the exact protocol v1 hello sizes and field order and reject truncated, extended, duplicate, or trailing hello bytes according to the state contract. 2. Unknown magic, unsupported version, nonzero status, reserved client flags, unreasonable maxFrame, timeout, and EOF close the generation with stable local reason codes and no downgrade guess. 3. Negotiated features are the supported intersection and negotiated maxFrame is bounded by both peers and local hard minimum or maximum policy before any envelope allocation. 4. Every split boundary and coalesced hello-plus-frame case produces the same result in Swift and relay implementations with fixed small buffers. 5. Tests cover success, all declared failure reasons, boundary limits, stale callbacks, cancellation, and privacy-safe diagnostics without reflecting attacker-controlled bytes.
