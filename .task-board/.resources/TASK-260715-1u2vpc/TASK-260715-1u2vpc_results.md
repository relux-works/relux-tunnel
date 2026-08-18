# TASK-260715-1u2vpc — libssh2 functional and rekey matrix

Recorded: 2026-08-18T19:12:00Z (current validation refresh)

## Verdict

**READY FOR REVIEW.** The selected libssh2 adapter's task-scoped M0 functional,
compatibility, macOS-build, rekey, pressure, cancellation, privacy, and cleanup
rows pass on current source `f5366fabdc37d429af84b10384842fd129eb2e45`.
The previously red common-conformance and aggregate-order dependencies are now
accepted `done`: `TASK-260715-2d3g5e` and `BUG-260728-2j25tu`. Full
`swift test` now exits 0 with 442 tests in 37 suites.

The owner-approved `owner-approved-m0-vs-release-gate-decoupling.md` makes
the accepted physical-Mac smoke (`TASK-260715-9yp8to`) the technical
prerequisite. It explicitly keeps `TASK-260715-2ayxqn`'s Apple account
readiness gap as a release-only gate, not a blocker for this protocol matrix.
This report does not alter or infer a release-readiness pass.

No mandatory red row is waived. The four M3-deferred semantics remain explicit
red states linked to `TASK-260728-3cveay`, and the physical M3 rows remain
separate from M0 selection evidence.

## Shared execution metadata

| Field | Value |
| --- | --- |
| Current device | Mac15,9; Apple silicon arm64; 128 GiB physical memory |
| OS/toolchain | macOS 26.5 (25F71); Xcode 26.5 (17F42); Swift 6.3.2 |
| Current source | `f5366fabdc37d429af84b10384842fd129eb2e45` (`main`, equal to `origin/main`) |
| Physical P0 source | `9f65158f415beef5abcbeae32a007d3a266ae7df` (accepted `TASK-260715-9yp8to` evidence) |
| Server | Real throwaway `/usr/sbin/sshd`, OpenSSH_10.2p1, loopback-only, per-test generated host and authorized keys, password/KBI/PAM disabled, forwarding enabled, `RekeyLimit 32K 0` |
| Dependency pin | libssh2 `a34302491c164d53c900fec9b3cbb050ecebe719` / reported `1.11.2_DEV`; OpenSSL `3.5.7`; patch SHA-256 `79e2464813e3c3add9486b2fb8c9e50004b48b246bbc771b5dd1675a152fa30e` |
| Public header pin | SHA-256 `aa542cff4e0e64927983da8c50b0315cd24c6d097fcdd42809d2e3b0878625bf` |
| Crypto backend | Statically linked OpenSSL 3.5.7 in `ReluxLibSSH2.xcframework`; system OpenSSH reports LibreSSL 3.3.6 only for the server executable |
| Primary algorithms | curve25519-sha256 / ssh-ed25519 / aes256-ctr / hmac-sha2-256 / Ed25519 public-key auth |
| Compatibility algorithms | diffie-hellman-group14-sha256 / ecdsa-sha2-nistp256 / aes128-ctr / hmac-sha2-512 / P-256 public-key auth |
| Adapter bounds | transport 64 KiB in matrix; channel receive 64 KiB; buffered read 16 KiB; queued write 32 KiB; write call 8 KiB; pending operations hard cap 64 |
| Standard timeouts | 10 s operation/rekey/close; keepalive interval 3,600 s unless a focused test injects a shorter deterministic value |
| Test traffic | loopback direct-tcpip echo, concurrent exec, stdin upload, 128 KiB server stream, 6 KiB byte-rekey trigger plus post-rekey traffic, pre/post time-rekey echo, partial/EAGAIN writes, 64-operation pressure, repeated cancellation, three lifecycle cycles |
| Sensitive material | Throwaway non-production keys created inside private temporary test directories and deleted by fixtures; no user key, passphrase, Keychain payload, token, or production endpoint was read |

## M0 viability matrix

Every row uses the shared metadata above. “Resources” refers to adapter-owned
resource assertions; physical RSS/scale/soak are deliberately separate M3 rows.

| Row | Configuration, traffic, duration, counters/resources | Result and raw evidence |
| --- | --- | --- |
| P0-MAC | Named Mac15,9 physical provider smoke: signed install, one PlugInKit provider/manager, ten start/v1-message/stop cycles, reinstall, final zero provider processes/crashes. | **PASS.** Accepted `TASK-260715-9yp8to_results.md` and reviewer evidence. Per owner decision this is the matrix's technical prerequisite; `TASK-260715-2ayxqn` remains a distinct blocked release/account gate. |
| APPLE-BUILD | Release, extension-safe macOS adapter and harness builds for arm64 and x86_64; pinned static libssh2/OpenSSL link. Current refresh: 24.03–24.83 s per target; no runtime resource measurement claimed. | **PASS.** Four current `swift build -c release ... -Xswiftc -application-extension` commands exit 0; archived `build-macos-{arm64,x86_64}.log` and `build-harness-{arm64,x86_64}.log`; fork/artifact verify exit 0. |
| E-ALGO | Real sshd forces both exact algorithm sets listed above. The session-reported KEX, host key, both ciphers, and both MACs must equal the caller allowlist; Ed25519 and P-256 opaque signers authenticate. 2 sessions, 0.197 s; both return owned resources to zero. | **PASS.** New `approvedAlgorithmCompatibilityMatrix`; `algorithm-compatibility.log`. Forbidden SHA-1/CBC values cannot be selected because each server/client list is a one-item approved set. |
| E-HOSTAUTH | Six untrusted/malformed/revoked/mismatched cases plus approved Ed25519/P-256. Host-policy trace must precede credential lookup; rejected cases assert credential calls=0, auth attempts=0, direct opens=0, exec opens=0. | **PASS.** `libssh2-full-coverage-tests.log`; tests `mandatoryHostPolicyOrdering`, `ed25519ExternalSignerAuthentication`, compatibility row. |
| E-CHANNELS | Direct-tcpip echo with exact destination/originator; concurrent exec; long-lived 128 KiB stdout; stdin upload to `cat >/dev/null`; sibling isolation across rejection, timeout, reset, and cancellation. M0 cycle asserts direct opens=1, exec opens>=4. | **PASS.** Current 61-test focused gate and 442-test full gate exit 0. Exact RFC reason and exec-exit semantics remain M3 red below. |
| E-BACKPRESSURE | 8 KiB write-call bound, 16 KiB read buffer, 32 KiB queued writes, 64 pending-operation hard cap; exact same-channel bytes across EAGAIN; excess pressure returns `resourceLimitExceeded`; close/free retry and cleanup. | **PASS.** Affected suite; pending count=64 before rejection; final owned snapshot zero. |
| E-WINDOW | 64 KiB initial policy plus bounded adapter intake/caller-sized prefixes; no Swift counter pretends to reverse wire credit. | **PASS for M0 bounds; RED / UNSUPPORTED for exact consumer-credit/cap/adjustment reporting.** `receiveWindow()==unsupported`; owner `TASK-260728-3cveay`. |
| E-REKEY | Manual/test callers coalesce; byte trigger at 4 KiB with 6 KiB payload; deterministic 100 ms time trigger; traffic survives; server `RekeyLimit 32K` forces inbound KEX under traffic. Swift counters: byte=1, time=1, successful>=1. C fixture: client rekey after 3 EAGAINs, post-rekey channels pass, 16 server-KEX transitions observed. | **PASS for client rekey and server-rekey-safe traffic. RED / UNSUPPORTED for exact server reason/generation/lifecycle in the neutral seam.** `libssh2-rekey.log`, affected suite; owner `TASK-260728-3cveay`. |
| E-KEEPALIVE | Manual and automatic sends use bounded scheduling; automatic send waits behind KEX without spending reply deadline; socket failure is fatal and privacy-safe. M0 cycle asserts sends>=1. | **PASS for transmission/failure handling. RED / UNSUPPORTED for reply-correlated RTT/timeout/miss reports in the neutral seam.** Owner `TASK-260728-3cveay`. |
| E-CANCEL | Resolution, connect/KEX, host decision, credential lookup, auth signer, rekey admission/caller, open, read/write/EOF, exec, upload source, keepalive, close, failed handshake, bridge operation, and non-cooperative dependency paths. Repeated cycles return channels/socket/session/tasks/allocations/buffered bytes to zero. | **PASS.** Current candidate-neutral cleanup matrix covers all 15 sites; focused 61-test gate exits 0. |
| E-ERRORS | Typed phase/scope/retry/teardown assertions for host, auth, channel, rekey, timeout, cancellation, socket, and cleanup failures; runtime error/privacy suites pass. | **PASS for M0 stable privacy-safe errors. RED / UNSUPPORTED for exact RFC channel-open reason.** Runtime rejection state is `unsupported`; owner `TASK-260728-3cveay`. |
| E-METRICS-PRIVACY | Available counters reconcile connect=1, auth=1, direct=1, exec>=4, rekey>=1, keepalive>=1; pressure/cancellation gauges return to zero. Full contract, diagnostics, system-domain Keychain, hostile-text, and redaction suites run in the aggregate gate. | **PASS.** Current full repository gate exits 0 with 442 tests; privacy sentinels remain absent. |
| E-INJECTION | Factory, resolver, connector, host policy, credential provider/external signer, clock, cancellation, logger, observer, metrics, and identity generator remain injected; macOS composition selects the pinned libssh2 factory. | **PASS.** Provider contract plus bounded-bridge tests in the 46-test affected gate. |
| KEYCHAIN | Accepted system-domain query invariant uses one explicit Keychain search list and opaque credential reference; configuration/seam contains no private key/passphrase bytes. Throwaway Keychain tests cover positive/negative lookup and privacy. | **PASS.** Full suite includes `macOS system-domain Keychain credential resolver`; accepted implementation evidence is recorded by `TASK-260715-1o9wjz`. |

## Four M3-deferred semantic states

These are evidence gaps, shown red, but they are not fabricated M0 failures.
All are owned by `TASK-260728-3cveay`.

| Deferred semantic | Capability state | Runtime state | M0 interpretation |
| --- | --- | --- | --- |
| Consumer-driven receive-window credit / immutable cap | **RED — unsupported** | `receiveWindow`, adjustments, credit, remaining-window gauges: `unsupported` | Bounded local buffers still pass; no exact wire-credit value is invented. |
| RFC 4254 channel-open rejection taxonomy | **RED — unsupported** | Rejected open: `channelOpenReason=unsupported`; other errors use `notApplicable` by contract | Stable M0 error/sibling isolation pass; no parsed prose or hard-coded `other`. |
| Exact exec-exit presence and `coreDumped` | **RED — unsupported** | Successful fixture exec/upload returns `SSHExecExit.notReported` | No hard-coded status 0 or `coreDumped=false`. |
| Deep server-rekey and keepalive observability | **RED — unsupported** | generation/server counts/active-KEX/reply/timeout/miss/RTT are `unsupported` | Client triggers and keepalive sends pass; C evidence does not get projected as invented neutral-seam values. |

## M3 physical evidence kept separate

| Row | State |
| --- | --- |
| Multi-gigabyte soak | **NOT RUN — M3**, owner `TASK-260715-2xx2tk` |
| 100/250/500/1,000-channel physical scale | **NOT RUN — M3**, owner `TASK-260715-2xx2tk` |
| Physical memory/extension footprint and soak | **NOT RUN — M3**, owner `TASK-260715-1k3wsk` |

No M3 physical number is used as M0 selection evidence.

## Validation gates

| Gate | Result |
| --- | --- |
| `make check-libssh2` | exit 0; static/extension-safe artifact, public APIs, symbols, lock, notices |
| `make test-libssh2-source-gates` | exit 0; archive/patch verification and tamper-negative gate |
| `make test-libssh2` | exit 0; real sshd client/server rekey and mixed-traffic evidence |
| `swift test --enable-code-coverage --filter LibSSH2` | exit 0; 61 tests / 4 suites / 49.599 s; 25 expected known issues are only the unavailable out-of-scope ReluxNIOSSH adapter rows |
| Affected adapter coverage | 82.94% regions (1,181/1,424), 94.61% functions (386/408), 91.97% lines (3,357/3,650) |
| Strict recursive `swift-format lint` | exit 0, zero output |
| macOS arm64/x86_64 adapter+harness extension-safe release builds | four exits 0 on current source |
| `make ssh-fixtures-test` | exit 0; 43 tests / 9.020 s; manifest, privacy, failure cleanup, macOS real-sshd profiles, rekey stream, and teardown pass |
| Full `swift test` | exit 0; 442 tests / 37 suites / 49.408 s; 25 expected known issues are confined to the unavailable ReluxNIOSSH candidate |
| Prior HEV aggregate-order regression | **RESOLVED.** `BUG-260728-2j25tu` is accepted `done`; current full suite is green. |

## Test-only change

The committed test delivery at `f5366fa` adds the candidate-neutral transport
matrix plus real-server compatibility and complete cancellation/lifecycle
coverage. The same accepted commit contains the minimal libssh2 transport
changes required by the common conformance suite; this run adds no uncommitted
product or test source changes.

## Raw artifacts

The attached `TASK-260715-1u2vpc_evidence.zip` contains the task-scoped
integration, compatibility, rekey, source-gate, artifact-verify, four macOS
build, coverage, lint, full-suite red, and isolated-reproduction logs. Key
SHA-256 values:

- affected test log: `2cfed2bfdd5b16f19eba1d7b1beb48c26e9885a76768912c711422bf4eb1c429`
- coverage report: `eb92edf63ca1011939f24adba4df5732d789d25a80806dee1b549556480b695c`
- rekey log: `1078a74230ce911e130d142202f304feb88bcd83d02b62fba9dd4028aae65e9c`
- full-suite red log: `69b4756b1c0dd2095498eb44ac1f66cc2e92dd233e10d75fdf72496b8702b043`

## Handoff disposition

Every M0 viability row is green and every task gate exits 0. The four exact M3
semantics remain explicit red `unsupported`/`notReported` states owned by
`TASK-260728-3cveay`; physical scale, memory, and soak remain unrun M3 evidence.
APC34W-B1–B3 still block release readiness, but the owner decision says they do
not block this protocol matrix. This task is ready for tester-to-review handoff.
