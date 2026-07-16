# Implement the SSH relay frame pump and bounded backpressure

## Description
Connect the client protocol codec to the long-lived relay exec channel with serialized bounded writes, incremental reads, queue admission, fair priority classes, saturation drops, cancellation, and session-generation cleanup.

## Scope
In scope: one reader and serialized writer ownership; handshake-to-framed transition; incremental frame decoding; vectored or chunked SSH writes; channel writability; total and per-association queued-byte caps; control and DNS versus general datagram scheduling hooks; frame and time budgets per callback; EAGAIN or window pressure; queue-full drop result; EOF; cancellation; metrics. Out of scope: SSH engine implementation, lane selection, protocol byte semantics, deciding final cap values before the limit decision, UDP sockets, DNS transaction logic, reconnecting a lost lane, and unbounded retry for reliable delivery.

## Acceptance Criteria
1. Frames are written in order within their required class and decoded in stream order while partial reads and writes never corrupt frame boundaries or association identity. 2. Total, per-association, frame-count, and outstanding-write ceilings reject or drop before allocation beyond the configured budget and control close or health frames cannot be starved by bulk datagrams. 3. SSH window pressure, partial write, EAGAIN, stall, queue saturation, EOF, channel error, cancellation, and provider stop produce deterministic results without busy-spin or unbounded retry. 4. Reader and writer callbacks are scoped to one relay generation and late completions cannot deliver into replacement associations or revive a failed session. 5. Fake-channel tests cover fragmentation, coalescence, mixed priorities, many associations, deliberate stalls, queue-full drops, close under pressure, cleanup, and reconciliation of frames, bytes, drops, retained buffers, and windows.
