# TASK-260715-1u2vpc reviewer verdict

Date: 2026-08-18
Role: reviewer
Verdict: ACCEPTED -> done
Reviewed source: f5366fabdc37d429af84b10384842fd129eb2e45

## Acceptance review

- AC1: The task-scoped matrix records all M0 rows with device/OS/server, source and dependency pins, crypto backend, approved algorithms, configuration, traffic, durations, counters/resources, raw evidence references, and explicit results.
- AC2: Production-adapter tests and real local OpenSSH evidence cover host-before-auth ordering, opaque external signing, direct-tcpip, exec/stdin upload, bounded pressure, client byte/time rekey, server-rekey-safe traffic, keepalive, cancellation/lifecycle baselines, Keychain/privacy invariants, and available metrics.
- AC3: All four M3 semantics remain explicit red unsupported/notReported states and link TASK-260728-3cveay; no exact value is invented.
- AC4: soak, physical scale, and footprint remain separate NOT RUN M3 rows.
- AC5: no mandatory M0 row is red or waived. Prior aggregate failures are resolved by accepted BUG-260728-2j25tu.

## Independent validation

- swift test: exit 0; 442 tests / 37 suites; 25 known issues are the explicit unavailable ReluxNIOSSH rows.
- swift test --enable-code-coverage --filter LibSSH2: exit 0; 61 tests / 4 suites.
- Fresh affected adapter coverage: 82.87% regions (1,180/1,424), 94.61% functions (386/408), 91.97% lines (3,357/3,650).
- make check-libssh2: exit 0.
- make test-libssh2-source-gates: exit 0.
- make test-libssh2: exit 0; client rekey after 3 EAGAIN results, post-rekey traffic passed, 16 server-KEX transitions observed.
- make ssh-fixtures-test: exit 0; 43 tests.
- strict recursive swift-format lint: exit 0, no diagnostics.
- macOS arm64/x86_64 extension-safe release builds for adapter and harness: four exits 0.
- git diff --check: exit 0.
- Dependency/patch pins reproduce: patch 79e24648...30e; public header aa542cff...25bf.

## Architecture and evidence note

The only production change in the reviewed delivery injects the channel-write call through the existing LibSSH2ChannelAPI seam, preserving actor ownership while enabling deterministic EAGAIN/cancellation testing. The matrix remains candidate-neutral test code.

TASK-260715-1u2vpc_evidence.zip intentionally retains the 2026-08-11 aggregate-red log; current 2026-08-18 command/output evidence is separately attached in the tester spawn transcript, and this reviewer independently reproduced all current green gates. The old red artifact is not relabeled or waived.