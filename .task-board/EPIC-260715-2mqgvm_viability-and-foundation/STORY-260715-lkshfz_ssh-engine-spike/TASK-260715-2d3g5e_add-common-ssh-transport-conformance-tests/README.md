# Add common SSH transport conformance tests

## Description
Implement one Swift Testing and harness suite that runs unchanged against both candidate adapters and verifies host policy, auth, channel semantics, exec, windows, rekey, backpressure, cancellation, metrics, and resource cleanup.

## Scope
In scope: fake-clock and deterministic socket or server fixtures; host-key first use, match, change, and rejection; Ed25519 and fallback auth; direct-tcpip and exec; concurrent channels; bounded write pressure; EOF, half-close, reset, and early close; window profiles; client byte and time rekey; server rekey; keepalive; cancellation at each state; metrics and descriptor baselines. Out of scope: candidate-specific pass exceptions, production lane scheduling, full physical performance matrix, relay framing, UI, and tests that rely only on sleeps.

## Acceptance Criteria
1. The same named suite runs against both adapters with candidate selection as data, and every gate has an explicit assertion rather than an informal log check. 2. Host verification tests prove policy sees raw key evidence before authentication acceptance and rejects a changed key without opening destination channels. 3. Channel tests verify independent open, bounded write, read, EOF, half-close, reset, cancel, close, and per-channel windows under concurrent activity. 4. Fake-clock and byte-count tests trigger client rekey; fixture-driven tests cover server rekey and active channels across key exchange. 5. Repeated cancellation at connection and channel states returns task, channel, socket, and descriptor counts to baseline and metrics use the common schema.
