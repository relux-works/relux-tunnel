# TASK-260715-gyg51r revision 4 review verdict

Verdict: **accepted** for `CR-TASK-260715-gyg51r-4` revision 4.

The exact candidate tree is
`82c5b2ce942d3d676a035c559ab80d54aa7ea05d`. All five working files match
their candidate blob OIDs. The exact base-to-candidate patch SHA-256 is
`7fe7beb110e9232f1f6397fa4e8f9c85b0a31024375911ee743381bf4068d054`.

## Independent evidence

- The three production-entry path-containment checks returned nonzero and
  created no file outside the approved directory. Source inspection confirms
  descriptor-anchored, no-follow component traversal and descriptor-relative
  atomic output writing with no pathname fallback after validation.
- A fresh-seed physical arm64 macOS 26.5 loopback run emitted all 36 rows.
  Nominal and mixed drops were zero. Every constrained-buffer and
  receiver-stall row had a nonzero, non-total, reason-specific drop, recovered,
  and reported zero production-owned descriptor delta. `taskDelta` remained
  semantically unavailable with explicit availability text.
- Three additional production runs at the 64-packet floor each emitted 36 rows
  and satisfied the same loss, recovery, descriptor, and accounting invariants.
- Requested/effective buffers, latency, throughput, CPU, packet/syscall rates,
  fragmentation limitation, and maximum datagram metrics are present. Native
  IPv6 rows ran; NAT64 and energy are explicitly unavailable; physical iPhone
  is deferred under ADR-024.
- `logicalBatchGroups == floor((packetsSent + 31) / 32)` for every row and is
  presented as derived, not observed batching.
- The measured recommendation remains injectable MTU `1500...4096` and
  requested buffers `32768...262144`. It explicitly rejects treating 8500
  loopback throughput as external path-MTU or fragmentation proof.

## Gates

- Focused Swift Testing: 29 tests, exit 0.
- Fresh coverage run: 86.08% regions, 90.35% functions, 95.98% lines for
  `MTUMatrixCommand.swift`, exit 0.
- Full Swift suite: first run exit 1 from one unrelated timing-sensitive SSH
  closure assertion; the exact SSH gate then passed in isolation, and the full
  rerun passed 478 tests in 40 suites with 25 declared known issues, exit 0.
  Both full-run exit codes are preserved in the attached evidence.
- Strict Swift format, core dependency/import boundary, exact candidate blob,
  diff, patch hash, privacy, safety, and authoritative board validation gates:
  exit 0.

No NetworkExtension, VPN preference, route, DNS, interface, packet-filter,
Keychain, signing, sudo, SSH, Internet, or global pressure state was touched.

Fresh raw matrix SHA-256:
`edaa6ad5a6ac32496b7c89dad597f85bdfc4d10c1a96cc778519ec71bb112357`.
