# Add bootstrap command, parser, and hostile-output tests

## Description
Build the deterministic security test suite for platform probing, typed command rendering, path validation, hash parsing, output bounds, secret exclusion, and bootstrap state transitions before remote matrix execution.

## Scope
In scope: golden rendered argv; shell metacharacters and control bytes; unicode and length policy; HOME and temporary path output; symlink and traversal fixtures; uname and hash output mutations; stdout and stderr ceilings; exit codes; timeout and cancellation; manifest tuple injection; log and error snapshots; property and fuzz cases; allocation and iteration bounds. Out of scope: live production hosts, actual four-target asset builds, SSH authentication, network-path failures, UDP framing, performance benchmarking, and keeping hostile raw data in logs.

## Acceptance Criteria
1. Golden tests prove every typed operation renders the expected argv and dynamic token as exactly one argument or rejects it before exec. 2. Fuzzing probe, path, hash, size, identity, stdout, and stderr parsers causes no command injection, crash, hang, uncontrolled recursion, unbounded allocation, or remote-text logging. 3. Traversal, symlink, ownership, permissions, leading dash, newline, NUL, whitespace, oversized, duplicate-record, and ambiguous-output cases map to stable local reason codes. 4. Secret-sentinel tests fail if profile credentials, key material, passphrases, destination data, raw command stdin, or attacker-controlled output appears in commands, logs, metrics, or errors. 5. Fake clocks and channels cover cancellation and timeout at every bootstrap state and return parser buffers, tasks, timers, and channel handles to baseline.
