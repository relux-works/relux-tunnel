# Run the ReluxNIOSSH functional and rekey matrix

## Description
Execute the complete candidate-neutral functional, compatibility, Apple-target, and rekey matrix against the ReluxNIOSSH adapter and preserve row-level evidence without treating the existence of the fork as a reason to accept it.

## Scope
In scope: macOS harness and provider; Gate P0 physical iPhone provider smoke; current OpenSSH Linux and macOS; older profile; real relux host; host verification; Ed25519 and fallback auth; direct-tcpip; exec stdio; 32 KiB, 64 KiB, and capped BDP windows; bounded pressure; client byte and time rekey; server rekey; at least 5 GiB mixed traffic; cancellation and network loss. Out of scope: libssh2 results, production lane scheduling, SFTP, release distribution, and fixing failures inside the measurement task.

## Acceptance Criteria
1. A TASK-ID-scoped matrix records device, OS, server, source and dependency revisions, algorithms, config, windows, traffic, duration, loss and latency, counters, resources, raw artifact locations, and pass or fail for every required row. 2. Raw host-key evidence precedes auth acceptance and Ed25519 plus the approved fallback pass against all in-scope servers, including real relux. 3. Direct-tcpip and exec remain correct under concurrent activity, pressure, half-close, reset, cancellation, and provider lifecycle. 4. Client byte and time rekeys plus server rekey survive at least 5 GiB of simultaneous direct and exec traffic without corruption, deadlock, or channel leak. 5. Any red row remains red, creates or references focused rework, and is not waived by the candidate implementation team.
