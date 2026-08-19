# TASK-260715-mocqmr rework-01 independent review contract

Review the complete task, but begin by independently reproducing the three
blocking findings in `TASK-260715-mocqmr_review-results.md`. Accept only if the
rework closes them without weakening the original acceptance criteria.

## Mandatory adversarial checks

1. Run a real fixture that attempts to daemonize/reparent a descendant and
   write outside the isolated runtime root. Verify the gate fails closed or the
   OS containment prevents both actions, and verify the reviewer leaves no
   process/file residue after the reproduction.
2. Review the macOS sandbox and Linux Landlock/seccomp implementations against
   their actual syscall/process semantics. Confirm Go runtime threads remain
   possible while process creation, sockets/listeners, and external writes are
   denied. Unsupported or unavailable containment must be an explicit red gate.
3. Exercise emulated commands with absolute/private-looking executable and
   emulator paths, oversized runner metadata, error strings, and argument
   lists. Confirm every retained report field is path-free, bounded, and uses a
   fixed vocabulary where appropriate.
4. Reproduce stdout contamination, identity mismatch, launch failure, timeout,
   and signal paths. Confirm every started process produces a deterministic
   failed-check record with its actual observed exit code and `processStarted`
   truth; `null` may not mask an observed exit.
5. Mutation-test target/arch/hash/size, symlink/non-executable/replaced assets,
   cleanup, root/emulation truth, output contamination, and missing native
   support.

## Regression and evidence gates

- Run the Python suite with `ResourceWarning` as errors and recompute affected
  coverage (minimum 80%).
- Run Python compilation/format, Actionlint, Go tests/vet,
  supply-chain/toolchain verification, and a fresh native Darwin arm64 gate
  with repeated SIGTERM/cleanup stress.
- Verify the four native CI rows, pinned tool inputs, `fail-fast: false`, exact
  target-matched runtime gating, red missing-runner behavior, and exact artifact
  retention.
- Inspect the final report for absolute paths, user/private identifiers,
  unbounded values, and secret-bearing error/command content.
- Preserve the build-only host policy: no signing, provider/app/VPN activation,
  `startVPNTunnel`, or route/interface/pf/DNS mutation.

Route accepted work to `done`; otherwise attach exact evidence and route to the
appropriate rework status. Do not accept based only on producer evidence.
