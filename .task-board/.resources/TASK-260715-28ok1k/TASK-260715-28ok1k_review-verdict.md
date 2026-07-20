# TASK-260715-28ok1k — Review verdict: ACCEPTED

Date: 2026-07-20
Reviewer: reviewer (claude)
Artifacts reviewed:
- `.research/260720_task-260715-28ok1k-ssh-engine-candidate-audit.md`
- `.research/260720_task-260715-28ok1k-ssh-engine-candidate-manifest.json`
- Board outcome copies under `.task-board/.resources/TASK-260715-28ok1k/`

## Verdict

Accepted → `done`. All five acceptance criteria are met, and every load-bearing
claim independently re-verified during review checked out exactly. No candidate
is favored; ADR-014 correctly remains open.

## Independent fact-check evidence

Every check below was reproduced by the reviewer from upstream sources on
2026-07-20, not taken from the audit text.

### Pins and hashes

| Claim | Verification | Result |
|---|---|---|
| swift-nio-ssh `0.14.1` → `31cdc3c3391a10460dedf1170530cf651d2ca496` | `git ls-remote` | match |
| libssh2-1.11.1 tag `3a73528…`, peeled `a312b43…` | `git ls-remote` (peeled) | match |
| All six transitive pins (swift-nio 2.101.3, swift-crypto 4.5.1, swift-asn1 1.7.1, swift-collections 1.6.0, swift-atomics 1.3.1, swift-system 1.7.4) | `git ls-remote` per tag | all match |
| nio-ssh archive SHA-256 `0b135087…` | downloaded codeload tarball, `shasum -a 256` | match |
| libssh2 archive SHA-256 `744ba3e9…` | downloaded codeload tarball, `shasum -a 256` | match |
| OpenSSL 3.5.7 archive SHA-256 `a8c0d28a…` | official published `.sha256` release asset | match |
| NIOSSH `LICENSE.txt` SHA-256 `cfc7749b…` | hashed from extracted archive | match |
| libssh2 `COPYING` SHA-256 `a83a4da2…` | hashed from extracted archive | match |

### Source-level gate claims (AC3)

| Claim | Verification | Result |
|---|---|---|
| NIOSSH hard-coded `targetWindowSize: 1 << 24` | raw file at pin, `SSHChannelMultiplexer.swift:211` | confirmed, exact line |
| NIOSSH `internal func _rekey()` test-oriented | raw file at pin, `NIOSSHHandler.swift:511` + comment | confirmed, exact line |
| libssh2 `LIBSSH2_CHANNEL_WINDOW_DEFAULT` = 2 MiB | `include/libssh2.h:787` at pin | confirmed |
| Public `libssh2_channel_open_ex` / `window_read_ex` / `receive_window_adjust2` / `session_hostkey` | header at pin | all public |
| `libssh2_channel_direct_tcpip_ex` hardcodes default window | `src/channel.c:384,457` at pin | confirmed |
| libssh2 inbound KEXINIT → internal `ssh2_kex_exchange(session, 1, …)`, not exported | `src/packet.c:1369` at pin + header check | confirmed |
| Version macro anomaly: `LIBSSH2_VERSION` `1.11.2_DEV` but `LIBSSH2_VERSION_NUM` `0x010b01` | header lines 46/68 at pin | confirmed |
| NIOSSH modern-only algorithms, no `ssh-rsa` anywhere in Sources | grep over extracted pin | confirmed |
| Upstream README: building blocks, not production-ready client | README at pin | confirmed |

### Security baseline (AC4)

| Claim | Verification | Result |
|---|---|---|
| NIOSSH GHSA-998x-vgvp-xwpc / CVE-2026-43798 critical, patched 0.14.1 | GitHub advisory API | confirmed |
| swift-crypto GHSA-8q93-f6xh-4f6f critical patched 4.5.1; GHSA-9m44-rr2w-ppp7 patched ≤4.5.1 | GitHub advisory API | confirmed |
| swift-nio GHSA-r3rc-9hpw-54v9 and GHSA-qcc5-f287-vgmq fixed by 2.101.3 | GitHub advisory API | confirmed |
| All six libssh2 CVE fix commits are ancestors of pin `a343024` | `git merge-base --is-ancestor` per commit in fresh clone | all six confirmed |
| 1.11.1 release commit is ancestor of pin | `git merge-base --is-ancestor` | confirmed |
| Pin commit dated 2026-07-19 | `git show -s` | confirmed |
| libssh2 issues #2023 (AEAD report) and #1925 (missing 1.11.2 release) open | GitHub issues API | both open, titles match |
| libssh2 679 commits in trailing 12 months | `git rev-list --count --since=2025-07-20` on pin | exactly 679 |
| `swift build -c release` succeeded at pin | analyst spawn log contains `Build complete! (37.01s)` | confirmed |

### AC coverage

- AC1: manifest carries exact commits, tags, transitive graph, archive/license/
  notice hashes, crypto backend, CMake/configure flags, upstream URLs, and
  inspected source paths. Spot-checked hashes all match.
- AC2: all 10 gates from `.spec/ssh-transport.md` engine decision matrix map to
  capability-matrix rows classified Public/Internal/Absent/Experiment.
- AC3: both window and rekey surfaces verified at exact pinned sources by the
  reviewer (table above).
- AC4: advisories, cadence, extension constraints, threading, allocator, and
  binary-size risks recorded and reproduced where checkable.
- AC5: 12 named experiments (E-NIO-APPLE … E-SUPPLYCHAIN) with owners and pass
  evidence; symmetric across candidates; no gate weakened; engine not selected.

## Review notes (non-blocking)

1. Release dates for NIOSSH 0.12.0/0.13.0/0.14.0 in the audit are tag-commit
   dates, not GitHub release `published_at` dates. Both are defensible; the
   tag dates match upstream exactly. No change needed.
2. swift-nio has two additional 2026 medium advisories (GHSA-rj37-6j9x-74q6,
   GHSA-cq87-8r7h-962v, HTTP paths, patched in 2.100.0) not enumerated in the
   audit. Both are fixed by the pinned 2.101.3, so the baseline conclusion is
   unchanged. E-SUPPLYCHAIN re-audit will re-enumerate anyway.
3. The libssh2 untagged-dev-commit pin is a real release-hygiene tradeoff; the
   audit flags it honestly and routes it to E-SUPPLYCHAIN rather than hiding it.

## Architecture fit

Consistent with ADR-005 (direct-tcpip + exec/stdio relay), ADR-006 (exec-stdin
upload, no SFTP), ADR-014 (selection stays open, gated on experiments), and
ADR-019 (ReluxNIOSSH source dep; libssh2 static XCFramework behind the native
seam). References the existing `SSHHostKeyEvidence` contract in
`Sources/ReluxTunnelCore/SSHContracts.swift`, which exists as claimed. This is
a read-only research task; no product code was modified, so no test run is
applicable beyond the audit's own pinned release build.
