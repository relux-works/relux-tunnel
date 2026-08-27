# TASK-260715-gyg51r revision 4 tester outcome

## Outcome

Ready for independent review. Revision 4 closes the ancestor-directory swap
escape while preserving the accepted MTU/socket-pressure implementation and
all revision-2/3 behavior.

The production output target is now opened during configuration parsing by
no-follow `openat` traversal from a filesystem-root descriptor. Every directory
descriptor is retained through the atomic temporary-file write and `renameat`.
Before writing, a second no-follow traversal compares every component's device
and inode with the retained chain; a root symlink, output-parent replacement,
or ancestor `RENAME_SWAP` produces nonzero exit and no external file. The
production-entry regression names `MTUMatrixHarnessCommand.run` and uses a
post-parse hook only to make the attack ordering deterministic.

## Physical loopback matrix

- Host: physical Apple M3 Max Mac (`Mac15,9`, stable identifiers omitted), arm64,
  macOS 26.5 build 25F71.
- Source: `a3a3352697686154fa69cc7c12d5eff9bec9d15c+rev4-worktree`;
  `MTUMatrixCommand.swift` SHA-256
  `b0bc55719aab4b1bc7e86a5f1de65acf868cc5ee321b753683c838f0df00d9e2`.
- Configuration: seed `2608270417`, 512 packets/row, loopback only, 36 rows:
  MTU 1500/4096/8500 × IPv4/native IPv6/dual stack × nominal/constrained-buffer/
  receiver-stall/mixed.
- Raw report SHA-256:
  `911f27ce08ff80a565a561e5128335a6a8a6065a102e7483eb5c9211a3229ada`.
- All nominal/mixed rows had zero loss. Every pressure row had a bounded,
  reason-specific non-total effect with consistent accounting and successful
  recovery. All rows reported zero production-owned socket descriptor delta;
  Swift-task delta remains explicitly null/unavailable.
- Requested/effective send and receive buffers matched at 4096, 32768, and
  262144 bytes.
- MTU totals across all family/pressure rows:
  - 1500: 6144 attempted, 3272 received, 2872 induced drops, zero sender
    refusals, maximum datagram 1472 bytes.
  - 4096: 6144 attempted, 3185 received, 2959 induced drops, zero sender
    refusals, maximum datagram 4068 bytes.
  - 8500: 6144 attempted, 3164 received, 2980 induced drops including 768
    sender refusals, maximum datagram 8472 bytes.
- Three additional production runs at the advertised 64-packet floor each
  produced all 36 valid rows with zero nominal/mixed loss and bounded pressure
  effects.
- Recommendation remains 1500 as the portable baseline, injectable 1500...4096
  only with end-to-end proof, and requested socket buffers 32768...262144.
  Loopback throughput is not external path-MTU/fragmentation proof; 8500 is not
  selected solely because it is an upstream default.

## Gaps and unavailable metrics

- Physical iPhone: `deferred-unavailable` under ADR-024, not a pass or failure.
- NAT64: unavailable because no authorized deterministic local environment was
  present and route/Internet mutation was prohibited.
- Energy: unavailable from the unprivileged SwiftPM harness; no sudo or
  `powermetrics` was used.

## Verification

- Focused Swift Testing: 29 tests in one suite, exit 0.
- Affected coverage: 86.08% regions, 90.35% functions, 95.98% lines.
- Full Swift suite: 478 tests in 40 suites, exit 0, with 25 declared known
  ReluxNIOSSH-adapter-unavailable issues. The unrelated
  `ClientUDPAssociationRegistry` flake did not reproduce.
- Swift format lint: exit 0 with no diagnostics.
- Core dependency/import boundary check: exit 0.
- Diff check, privacy/safety scan, and authoritative board validation: exit 0.

## Attached evidence names

- `TASK-260715-gyg51r_rev4-raw-matrix.json`
- `TASK-260715-gyg51r_rev4-physical-run.log`
- `TASK-260715-gyg51r_rev4-floor-repeat.log`
- `TASK-260715-gyg51r_rev4-focused-coverage.log`
- `TASK-260715-gyg51r_rev4-full-tests.log`
- `TASK-260715-gyg51r_rev4-validation.log`
