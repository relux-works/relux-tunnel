# TASK-260715-gyg51r — macOS MTU and socket-pressure matrix

## Outcome

The bounded `ReluxTunnelHarness mtu-matrix` run passed on a physical Apple M3 Max Mac (`Mac15,9`, arm64), macOS 26.5 build 25F71. It executed 36 loopback-only rows: MTU 1500/4096/8500 × IPv4/native IPv6/dual stack × nominal/constrained-buffer/receiver-stall/mixed bidirectional traffic. Every row records exact source/dependency/configuration metadata in the raw JSON.

- Source baseline: `a3a3352697686154fa69cc7c12d5eff9bec9d15c` plus this task's working-tree matrix implementation.
- Dependencies: HEV `ad7600497931205105b08367bd1b450048157e40`; libssh2 `a34302491c164d53c900fec9b3cbb050ecebe719`; OpenSSL `openssl-3.5.7`.
- Generator: 512 attempted datagrams per row using DNS-sized (128-byte), short-web (up to 768-byte), half-MTU, and maximum configured payloads; mixed rows alternate both socket directions.
- Buffers: requested/effective `262144/262144` bytes nominal and mixed, `4096/4096` constrained, `32768/32768` receiver stall.
- Safety: numeric loopback endpoints only. No NetworkExtension, VPN preferences, routes, DNS, interfaces, packet filters, SSH, Internet traffic, sudo, or global pressure tools were used.

## Analyzed matrix

Values aggregate the three family rows for each MTU/pressure pair. Throughput and packet-rate columns show the per-family range; CPU is user+system time summed across the three rows. Full per-row durations, bytes, batches, syscall counts, p50/p95 latency, CPU split, buffer limits, fragmentation observation, and lifecycle values are in the raw JSON.

| MTU | Pressure | Received / attempted | Send refusal | Queue drop | Worst p95 | Throughput range | Packet rate range | CPU total | Observed max datagram |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 1500 | nominal | 1536/1536 | 0 | 0 | 0.086ms | 297.38–503.34Mbps | 48,134–81,870pps | 16.38ms | 1452/1472B |
| 1500 | constrained | 34/1536 | 0 | 1502 | 2.618ms | 3.37–3.87Mbps | 938–1,120pps | 8.20ms | 1452/1472B |
| 1500 | receiver stall | 166/1536 | 0 | 1370 | 31.221ms | 6.54–6.96Mbps | 1,103–1,181pps | 8.45ms | 1452/1472B |
| 1500 | mixed | 1536/1536 | 0 | 0 | 0.062ms | 305.50–431.62Mbps | 49,449–70,205pps | 15.92ms | 1452/1472B |
| 4096 | nominal | 1536/1536 | 0 | 0 | 0.035ms | 714.27–805.10Mbps | 51,143–57,771pps | 21.08ms | 4048/4068B |
| 4096 | constrained | 20/1536 | 0 | 1516 | 3.052ms | 3.24–3.89Mbps | 529–636pps | 9.30ms | 4048/4068B |
| 4096 | receiver stall | 90/1536 | 0 | 1446 | 32.949ms | 6.41–7.34Mbps | 564–652pps | 10.06ms | 4048/4068B |
| 4096 | mixed | 1536/1536 | 0 | 0 | 0.052ms | 591.40–900.62Mbps | 42,345–64,625pps | 20.82ms | 4048/4068B |
| 8500 | nominal | 1536/1536 | 0 | 0 | 0.040ms | 1128.46–1267.67Mbps | 41,521–46,694pps | 29.23ms | 8452/8472B |
| 8500 | constrained | 34/1536 | 768 | 734 | 2.937ms | 3.16–3.72Mbps | 882–1,082pps | 9.18ms | 768B |
| 8500 | receiver stall | 58/1536 | 0 | 1478 | 34.024ms | 6.39–7.12Mbps | 271–478pps | 12.08ms | 8452/8472B |
| 8500 | mixed | 1536/1536 | 0 | 0 | 0.058ms | 1116.69–1310.73Mbps | 41,088–48,280pps | 28.99ms | 8452/8472B |

Nominal and mixed rows had zero unexplained loss. Every constrained/stalled row produced bounded, named drops and recovered on the same descriptors. The production-owned descriptor ledger returned to zero in all 36 rows and three repeated 36-row tests. Swift-task delta is explicitly `null`/unavailable because the synchronous runner owns no tasks; process-global threads are not used as a proxy. At MTU 8500 with a 4096-byte send buffer, half the attempts failed locally with errno 40 (`Message too long`); the largest successful constrained datagram was 768 bytes. This is separate from receive-queue overflow and is recorded separately.

Fragmentation is not directly observable through the UDP socket API; generators cap payloads to MTU minus IPv4/IPv6+UDP headers. Therefore loopback throughput does not prove external path-MTU or fragmentation safety. Energy is explicitly unavailable because the unprivileged SwiftPM harness has no per-process energy counter; `powermetrics`/sudo were not invoked.

## Recommendation

Keep 1500 as the portable baseline and expose 1500...4096 as an injectable candidate range only where end-to-end path evidence exists. Do not select 8500 from the upstream default or loopback throughput: it fails with the smallest measured socket buffer and has no external fragmentation/path proof. Use requested socket buffers in the measured 32768...262144-byte range; 4096 bytes remains fault-injection only.

## Deferred and unavailable rows

- Physical iPhone: `deferred-unavailable` under ADR-024, neither pass nor failure.
- NAT64: `unavailable`; no authorized deterministic local NAT64 environment was present, and the brief prohibited Internet traffic and route mutation.
- Native IPv6: available and passed over `::1`; no blocker was inferred from proxy evidence.

## Revision 3 containment and lower-bound rework

The production writer now classifies only lexical project `.temp` and explicit
`/tmp` roots, opens every project directory with `openat` plus `O_NOFOLLOW`, and
holds those directory descriptors through an `O_EXCL` temporary write and
same-directory `renameat`. A project `.temp` symlink to `/tmp` therefore fails
closed, while explicit `/tmp` remains supported through its separately
canonicalized system root. Parent rename/symlink replacement cannot redirect a
write through a re-resolved pathname.

Production-entry negative tests reproduce both prior bypass shapes. Before the
fix, the post-parse replacement test observed exit 0 and an external file; the
new gate returns nonzero and leaves the external target absent. The exact
`.temp -> /tmp` cross-root test is also rejected. The advertised 64-packet floor
now passes all 36 rows: a dual-stack receiver-stall half-row requests the real
4096-byte fault-injection ceiling when its 32-packet half would otherwise fit in
32768 bytes. Counters remain derived from actual Darwin socket results.

## Reproduction and evidence

```bash
swift run ReluxTunnelHarness mtu-matrix --configuration .temp/TASK-260715-gyg51r/matrix-physical-config.json
swift test --enable-code-coverage --filter ReluxTunnelHarnessTests
xcrun llvm-cov report .build/arm64-apple-macosx/debug/ReluxTunnelPackageTests.xctest/Contents/MacOS/ReluxTunnelPackageTests -instr-profile .build/arm64-apple-macosx/debug/codecov/default.profdata Sources/ReluxTunnelHarnessSupport/MTUMatrixCommand.swift
swift test
swift format lint Sources/ReluxTunnelHarnessSupport/MTUMatrixCommand.swift Sources/ReluxTunnelHarnessSupport/SmokeCommand.swift Tests/ReluxTunnelHarnessTests/HarnessTests.swift
```

- Raw matrix: `.temp/TASK-260715-gyg51r/TASK-260715-gyg51r_raw-matrix.json` (`SHA-256 c2757bae4b91a62f57511948b040e3352b673c185571db7ddb4077e7e980c63f`).
- Physical run: `.temp/TASK-260715-gyg51r/rev3-physical-matrix-01.log` (exit 0); independent invariant analysis: `rev3-matrix-analysis-02.log` (exit 0).
- Negative evidence: `rev3-negative-tests-red-03.log` proves the old post-parse external write and 64-floor failure; `rev3-negative-tests-green-02.log` and `rev3-focused-tests-01.log` pass the corrected production entry.
- Full suite: `.temp/TASK-260715-gyg51r/rev3-full-tests-02.log` — 477 tests, 40 suites, exit 0; 25 pre-existing declared known issues for the unavailable ReluxNIOSSH adapter.
- Focused coverage: `.temp/TASK-260715-gyg51r/rev3-focused-coverage-01.log` — 28 tests; 85.84% regions, 89.11% functions, 95.86% lines, exit 0.
- Lint/diff/privacy/safety: `.temp/TASK-260715-gyg51r/rev3-lint-diff-safety-02.log`, exit 0 with no diagnostics.

Two red full-suite runs proved that process-global FD/thread snapshots are invalid while unrelated suites run concurrently. The production runner now records an explicit owned-socket ledger around every `Darwin.socket` and successful `Darwin.close`; three repeated matrices exercise that ledger without accepting foreign process resources. Swift-task state is reported unavailable rather than inferred. The full suite then passed without weakening the owned-resource gate.
