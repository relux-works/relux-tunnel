# TASK-260715-1gjxer — independent reviewer verdict

## Verdict

ACCEPTED. ADR-014 records the approved libssh2 M0 selection with no waived red selected-engine gate. ReluxNIOSSH remains row-level comparative FAIL or NOT RUN evidence and receives no further fork work absent a revalidation trigger.

## Acceptance evidence

- AC1–AC3: the ADR maps every mandatory M0 gate for both candidates. Every selected libssh2 row is PASS, including macOS integration, pre-auth host policy, approved public-key auth and algorithms, concurrent direct-tcpip, long-lived exec and stdin upload, client and server rekey, bounded buffers and harness memory, deterministic cancellation, privacy-safe diagnostics, Keychain posture, keepalive, lifecycle cleanup, and real relux-server compatibility. No threshold was weakened; any future selected-engine red reopens analysis or the retained alternate.
- AC4: exact libssh2, OpenSSL, patch, header, artifact, and ReluxNIOSSH pins and hashes are explicit. The candidate-neutral adapter boundary, approved primary and fallback algorithms, injectable 32–64 KiB initial windows, 4 KiB–5 GiB byte rekey range, 100 ms–1 hour time range, executed 10 s M0 completion timeout, license notices, advisory monitoring, and TASK-260728-3cveay rebase ownership are explicit.
- AC5: all four M3-deferred semantics and their owner, physical scale and extension-memory evidence still owed, rejected evidence, residual risks, revalidation triggers, M1 and M2 consumers, and DNS residual gates are explicit. No physical or extension-budget number is asserted from the macOS harness.
- Architecture and planning: the implementation remains behind ReluxTunnelCore candidate-neutral contracts; only ReluxTunnelLibSSH2Adapter imports the native module. No new board element or diagram was needed, existing dependencies remain linked, and the ADR contains the required self-verified gap record for the rekey envelope.
- Cleanup anomaly closure: an independent opted real-host run exited 0 in 23.799 s with auth=1, direct=2, exec=7, rekeys=1, cleanup_zero=true. A subsequent exact process scan found no task-created outer relux SSH forwarding process.

## Independent gate exits

- RELUX_RUN_REAL_HOST_LIBSSH2=1 swift test --filter approvedRealReluxHostCompatibility: exit 0; 1 test passed.
- swift test: exit 0; 443 tests in 37 suites passed with 25 explicit ReluxNIOSSH known-issue rows; ordinary real-host row reported NOT RUN because opt-in was absent.
- make validate-libssh2: exit 0.
- make test-libssh2-source-gates: exit 0.
- swift format lint --strict --recursive Sources Tests Package.swift: exit 0.
- git diff --check: exit 0.
- Attached precondition byte counts and SHA-256 digests match the assignment.

During reviewing, task-board validate returned exit 0 while reporting the hard-blocked parent story as analysis versus the child reviewing aggregate. This is transient under the documented blocked-parent aggregation rule and must clear when the accepted leaf transitions to done. The reviewer supplies no commit_ack.