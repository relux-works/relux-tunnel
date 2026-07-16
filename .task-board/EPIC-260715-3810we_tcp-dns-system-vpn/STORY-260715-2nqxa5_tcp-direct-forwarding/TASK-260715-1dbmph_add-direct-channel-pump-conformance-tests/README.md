# Add direct-channel and byte-pump conformance tests

## Description
Build a candidate-neutral test suite around a fake SSH transport and controllable local stream to verify direct-tcpip open mapping, success and failure replies, bounded full-duplex transfer, writability pressure, EOF and half-close, resets, cancellation, deadlines, late callbacks, and cleanup.

## Scope
In scope: IPv4, IPv6, and domain mapping, originator policy, channel window policy input, open rejection and timeout, randomized byte streams, partial I/O, independent pressure, all terminal races, admission release, metrics, fake clocks, and repeated resource baselines. Out of scope: real OpenSSH, HEV integration, physical devices, parser fuzzing owned separately, performance claims, lanes, UDP, and reconnect.

## Acceptance Criteria
1. The same named suite runs against all production adapter conformers through shared protocols with no selected-engine type in test expectations. 2. Channel-open assertions prove exact endpoint, originator, policy, once-only attempt, success ordering, and late-open cleanup. 3. Pump assertions prove exact bidirectional hashes and fixed queued-byte ceilings under fragmented reads, partial writes, and alternating pressure. 4. A state-table covers EOF, half-close, reset, rejection, timeout, session loss, provider stop, and concurrent terminal callbacks. 5. At least one thousand deterministic short-flow cycles show zero registry, channel, socket, buffer, task, timer, or reservation growth.
