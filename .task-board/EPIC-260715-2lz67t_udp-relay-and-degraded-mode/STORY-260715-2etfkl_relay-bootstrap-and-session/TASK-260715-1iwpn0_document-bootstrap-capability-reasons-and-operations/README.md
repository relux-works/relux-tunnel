# Document bootstrap capability reasons and operator procedures

## Description
Document the implemented remote deployment and relay-session lifecycle, including trust ordering, commands, private paths, checksum fallbacks, atomic install, health, stable capability reasons, redacted diagnostics, recovery, and reproducible tests.

## Scope
In scope: authenticated-SSH precondition; platform mapping; asset and manifest selection; fixed command families; cache and temporary path policy; upload backpressure; size and hash verification; safe readback fallback; install and reuse; stdio launch; handshake and health; failure and reason table; cleanup; privacy; test commands; troubleshooting. Out of scope: credentials, SFTP guidance, root or system service installation, UDP association internals, user interface copy, M3 network reconnect, standalone relay distribution, and changing implementation behavior during documentation.

## Acceptance Criteria
1. Sequence and trust-boundary diagrams show host verification and authentication before probe, local asset validation before upload, remote verification before execution, handshake before capability, and cleanup on every failure. 2. Tables enumerate every supported platform tuple, directory fallback, command family, bound, timeout, reason code, diagnostic field, and operator action without exposing dynamic secrets or unsafe copy-and-paste shell. 3. The document states that no known checksum mismatch executes and explains utility and bounded readback verification plus secondary self-hash identity evidence. 4. Reproduction commands cover unit, hostile parser, four-target build, controlled-host matrix, session health, and repeated cleanup with expected pass and failure outputs. 5. Troubleshooting covers unsupported platform, read-only or noexec host, missing tools, mismatch, incompatible protocol, process exit, and redacted support collection and links all consuming capability tasks.
