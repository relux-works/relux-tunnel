# Integrate the libssh2 candidate adapter

## Description
Implement the libssh2 candidate behind the common SSH transport contract, including nonblocking socket integration and bounded async adaptation, and build it in the macOS harness and both Apple provider configurations without masking unsupported gates.

## Scope
In scope: pinned libssh2 and crypto backend; extension-safe static or source build; session handshake; raw host-key access; approved public-key auth; direct-tcpip; bidirectional exec; custom receive-window experiment; rekey behavior; nonblocking EAGAIN integration; bounded buffers; cancellation; keepalive; metrics; error mapping; allocator hooks where supported; harness registration. Out of scope: patching libssh2 to force a pass without a separate recorded decision, blocking calls on provider executors, SFTP, password prompts, ProxyJump, agent forwarding, production lane scheduling, and candidate types outside the adapter.

## Acceptance Criteria
1. The adapter builds from pinned source with the approved crypto backend for macOS harness, macOS provider, iOS simulator, and Gate P0 iPhone configurations and exposes no libssh2 type across the shared boundary. 2. Socket readiness and LIBSSH2_ERROR_EAGAIN are integrated without busy spinning or unbounded buffering, with deterministic cancellation and timeout behavior. 3. Raw host-key evidence, public-key auth, direct-tcpip, bidirectional exec, EOF and half-close, keepalive, metrics, and privacy-safe errors conform or are marked red with reproducible evidence. 4. Initial channel window and adjustment control plus client and server rekey behavior are proven through supported APIs or explicitly fail the candidate; no hidden fallback weakens the contract. 5. Repeated connect and cancel smoke runs return sessions, channels, sockets, tasks, and custom allocations to baseline.
