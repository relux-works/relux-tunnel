# Run the libssh2 functional and rekey matrix

## Description
Execute the complete candidate-neutral functional, compatibility, Apple-target, and rekey matrix against the libssh2 adapter and preserve row-level evidence, including explicit red results for unsupported window or rekey control.

## Scope
In scope: macOS harness and provider; Gate P0 provider smoke on the physical Apple-silicon Mac; current OpenSSH Linux and macOS; older profile; real relux host; host verification; Ed25519 and fallback auth; direct-tcpip; exec stdio; 32 KiB, 64 KiB, and capped BDP window attempts; bounded pressure; client byte and time rekey attempts; server rekey; at least 5 GiB mixed traffic when safe; cancellation and network loss. Out of scope: NIOSSH results, production lane scheduling, SFTP, release distribution, patching the library inside the measurement task, and waiving an unavailable API.

## Acceptance Criteria
1. A TASK-ID-scoped matrix records device, OS, server, source and dependency revisions, crypto backend, algorithms, config, windows, traffic, duration, loss and latency, counters, resources, raw artifact locations, and pass or fail for every row. 2. Raw host-key evidence precedes auth acceptance and Ed25519 plus the approved fallback pass against all in-scope servers, including real relux. 3. Direct-tcpip and exec remain correct under concurrent activity, nonblocking pressure, half-close, reset, cancellation, and provider lifecycle. 4. Window and rekey rows prove the required control through supported behavior or remain explicit red; a safe 5 GiB mixed run verifies content and resource cleanup when the candidate reaches that gate. 5. Any red row remains red, creates or references focused rework, and is not waived because another libssh2 feature passes.
