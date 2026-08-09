# Run the libssh2 functional and rekey matrix

## Description
Execute the candidate-neutral M0-viability functional, compatibility, macOS-target, and client-rekey matrix against the libssh2 adapter, while recording the four M3-deferred semantics as explicit evidence states rather than M0 failures or fabricated passes.

## Scope
In scope: macOS harness and provider; Gate P0 provider smoke on physical Apple silicon; target servers and approved algorithms; host-before-auth; direct-tcpip; exec/stdin upload; bounded buffers/pressure; client byte/time rekey; safe server-rekey handling; keepalive; cancellation/lifecycle; available metrics; privacy checks; explicit M3 deferred-state rows. Out of scope: requiring consumer-credit caps, RFC open reasons, exact exec-exit presence/coreDumped, or deep rekey/keepalive telemetry for M0 viability; NIOSSH work; production lane scheduling; SFTP; release distribution; patching inside measurement; silent waiver of any mandatory row.

## Acceptance Criteria
1. A TASK-ID-scoped matrix records every M0-viability row with device, OS, server, source/dependency revisions, crypto backend, algorithms, configuration, traffic, duration, counters, resources, raw artifacts, and pass or fail. 2. Host-key evidence precedes authentication; approved auth, direct-tcpip, exec/stdin upload, bounded pressure, client rekey, server-rekey-safe traffic, cancellation/lifecycle, Keychain/privacy invariants, and available observability satisfy the M0-viability tier. 3. Each of the four M3-deferred semantics records reported, not-reported, or unsupported and links TASK-260728-3cveay; no exact value is invented. 4. Safe soak and physical-scale rows remain separate M3 physical evidence and do not masquerade as M0 selection input. 5. Any mandatory red row remains red, creates or references focused rework, and is never waived because another libssh2 feature passes.
