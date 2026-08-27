# TASK-260715-gyg51r — revision 3 tester verification

## Outcome

Ready for independent review. Revision 3 closes the production output-path
TOCTOU finding with descriptor-bound no-follow traversal and atomic writing,
and makes the advertised 64-packet floor reproducible with real bounded socket
pressure. No NetworkExtension, VPN, route, DNS, interface, packet-filter, SSH,
Internet, sudo, Keychain, or global pressure action was used.

## Negative evidence

- Before the fix, `swift test --filter
  'HarnessTests/matrixProductionPath(RejectsPostParseParentReplacement|RejectsProjectTempRootSymlink|SupportsMinimumPacketCount)'`
  exited 1: the post-parse swap returned command exit 0 and wrote the external
  file, while the 64-packet row failed its pressure requirement. Evidence:
  `rev3-negative-tests-red-03.log`.
- After the fix, the same three production-entry tests exited 0. A lexical
  project `.temp` symlink to `/tmp` and a post-parse parent replacement both
  return nonzero without an external file; the 64-packet matrix succeeds.
  Evidence: `rev3-negative-tests-green-02.log`.

## Matrix evidence

- Command: `swift run ReluxTunnelHarness mtu-matrix --configuration
  .temp/TASK-260715-gyg51r/matrix-physical-config.json`.
- Physical Apple-silicon Mac, arm64, macOS 26.5 build 25F71.
- 36 unique rows: MTU 1500/4096/8500 × IPv4/native IPv6/dual stack ×
  nominal/constrained-buffer/receiver-stall/mixed; 512 attempts per row.
- Nominal and mixed loss: zero. All 18 pressure rows: nonzero, non-total,
  reason-specific loss with exact accounting, successful recovery, zero owned
  descriptor delta, and explicit null/unavailable task delta.
- Raw SHA-256:
  `c2757bae4b91a62f57511948b040e3352b673c185571db7ddb4077e7e980c63f`.
- Production run: `rev3-physical-matrix-01.log`, exit 0. Independent invariant
  analysis: `rev3-matrix-analysis-02.log`, exit 0.
- Physical iPhone remains ADR-024 `deferred-unavailable`; NAT64 and energy are
  named unavailable gaps. Native IPv6 ran on `::1`.

## Gates

- Focused final test: 28 tests in one suite, exit 0
  (`rev3-final-focused-tests-01.log`).
- Coverage run: 28 tests, exit 0; affected file 85.84% regions, 89.11%
  functions, 95.86% lines (`rev3-focused-coverage-01.log`).
- Full Swift suite: 477 tests in 40 suites, exit 0, with 25 existing declared
  ReluxNIOSSH-unavailable known issues (`rev3-full-tests-02.log`).
- Strict affected-file Swift format, diff, privacy, and safety scan: exit 0
  (`rev3-lint-diff-safety-02.log`).
- Complete candidate diff inspected from `rev3-candidate-diff-01.log`.

The measured recommendation remains MTU 1500 as the portable baseline,
1500...4096 only as an injectable range with end-to-end path evidence, and
requested buffers 32768...262144 bytes. MTU 8500 is not selected from upstream
default or loopback throughput alone; 4096 bytes remains fault injection.
