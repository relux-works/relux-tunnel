# Pin and audit the SSH engine candidates

## Description
Establish exact source baselines for SwiftNIO SSH and libssh2 and document their current Apple integration, host-key, authentication, channel, window, rekey, cancellation, algorithm, license, security, and maintenance surfaces before candidate work begins.

## Scope
In scope: the inspected SwiftNIO SSH commit and transitive SwiftNIO pins; a specific libssh2 commit or release and crypto backend; source hashes; licenses and notices; iOS and macOS build support; extension safety; known CVEs and advisories; raw host-key access; auth algorithms; direct-tcpip and exec; initial windows; rekey APIs; thread and allocator model; cancellation; open upstream issues. Out of scope: changing candidate code, selecting the winner, configuring production lanes, SFTP, or accepting marketing claims without source evidence.

## Acceptance Criteria
1. A TASK-ID-scoped manifest records exact commits, tags where applicable, transitive dependencies, hashes, crypto backend, build flags, upstream URLs, licenses, notices, and inspected source paths. 2. A capability table maps every M0 SSH gate to a public API, internal hook, confirmed absence, or experiment still required for each candidate. 3. The SwiftNIO SSH 16 MiB child-window default and non-public client rekey surface are verified at the pinned source; libssh2 window and rekey behavior is equally source-pinned. 4. Current security advisories, maintenance cadence, extension constraints, threading, allocator, and binary-size risks are recorded. 5. Unknowns become concrete dependent experiments and no candidate is favored by weakening a missing capability.
