# TASK-260715-2jatnd rework handoff evidence

## Outcome

Ready for independent review. The TASK-scoped ADR records the macOS-first M0
Bridge gate as passed while preserving every red or deferred row independently:
MTU 8500 remains failed as the default, MTU 4096 remains blocked as a default,
and physical iPhone, NAT64, sleep/wake, whole-extension memory, and HEV fork
authorization remain blocked, deferred, or rejected exactly as the accepted
evidence requires.

The selected initial values remain MTU 1500, requested 32768-byte socket
buffers with effective-value readback, 64-packet and 5-ms pump budgets, HEV
task-stack/TCP/UDP-copy values 24576/4096/2, and a measured 500-session ceiling.
Unmodified pinned HEV is retained; no fork is authorized without target
Instruments evidence and a measured callback prototype with regression and
rebase coverage.

## Revision-1 review findings resolved

1. The ADR traceability table now covers all 12 direct Story children. The
   previously omitted `BUG-260720-2zh86a` row records its atomic vendor-build
   deliverable, ADR-016/validation specification trace, exact gap, and the
   upstream-C/MTU/framing/route/DNS/SSH/relay out-of-scope checks.
2. The bounded-backpressure row now names the original red resources
   `TASK-260715-35wctc_stop-line.md` and
   `TASK-260715-35wctc_real-hev-counter-regression.log`, then separately names
   the resolving accepted resources `BUG-260720-2p4fln_rework-01-results.md`
   and `BUG-260720-2p4fln_review2-verdict.md`. The red post-stop counter result
   is preserved and is not relabeled as accepted evidence.

## Repository artifacts

- `docs/TASK-260715-2jatnd_m0-bridge-hev-decision-adr.md`
- `.spec/decisions.md`
- `.spec/packet-plane.md`
- `README.md`
- `LOGBOOK.md`

ADR SHA-256:
`f2dc587541386cdc5eb7e10328adda21b8bbba3af32d5c722e62616a2abca173`.

## Validation in this rework run

- Documentation and diff validation: exit 0. It proves all 12 direct child IDs
  have trace rows, exact red-to-resolution resources are named, selected values
  are present, red/deferred rows remain present, and `git diff --check` passes.
  Log: `docs-validation-02.log`; SHA-256
  `2502bdb095cd809636ebdca8342ec5af609024ccca283956855825fcb27ff765`.
- Authoritative `task-board validate`: exit 0, `Board is valid. No issues found.`
  Log: `board-validation-02.log`; SHA-256
  `6eac60d98a0b8b4bb611aa347c4b01a8651c58a62a3363ff88e666814d7402ba`.
- No source code changed in revision 1 or this rework. Swift, TSan, fuzz, physical
  MTU, pressure, lifecycle, and memory conclusions are consumed from the
  already accepted exact-tree resources named in the ADR; they were not rerun
  or represented as new evidence in this documentation-only synthesis.

No NetworkExtension or VPN was installed, signed, loaded, enabled, configured,
or connected. No route, DNS, interface, packet filter, SSH session, global
pressure, staging, commit, rebase, merge, or branch switch was performed.
