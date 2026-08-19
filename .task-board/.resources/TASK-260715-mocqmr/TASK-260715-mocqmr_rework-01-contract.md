# TASK-260715-mocqmr rework-01 contract

The independent reviewer requested changes. Treat
`TASK-260715-mocqmr_review-results.md` as authoritative reproduction evidence
and make the smallest architecture-sound correction that closes every finding.

## Required fixes

1. The runtime gate must fail closed when any relay-started descendant survives,
   including a process that daemonizes, creates a new session/process group, or
   becomes reparented. Cover this with a real adversarial fixture, not only a
   mocked observer result. Cleanup by the test harness is allowed after the gate
   has first detected and reported the failure; never leave the fixture alive.
2. Writes outside the isolated runtime area must be prevented or observed and
   must fail the gate. The proof must cover the reviewer's detached fixture that
   writes under a shared temporary location. Do not claim that scanning only
   `runtime_root` proves absence of external writes. Prefer an enforceable,
   portable containment/observation boundary; if no honest boundary exists on
   one native runner, emit an explicit red unsupported gate instead of passing.
3. Make every report field path-free and bounded, including emulator argv,
   executable argv positions, runner names, error strings, and metadata. Do not
   retain absolute paths under a different field or basename-derived secret.
   Add native and emulated regression fixtures with private-looking paths and
   oversized metadata.
4. Preserve the observed exit code and deterministic failed-check record on
   every subprocess failure path, including stdout contamination and identity
   mismatch. A missing exit code is allowed only when no process was actually
   started/observed, and that distinction must be explicit.
5. Record the escaped-descendant/external-write finding and resolution in
   `LOGBOOK.md`. Update task outcome evidence rather than weakening the AC.

## Verification

- Run all 13 existing unit tests with `ResourceWarning` promoted to errors and
  add focused regressions for all findings above.
- Recompute affected-code coverage and keep it at least 80%.
- Run Python compilation, Actionlint, Go tests/vet, supply-chain/toolchain
  checks, a fresh native Darwin arm64 gate, and repeated SIGTERM/cleanup stress.
- Mutation-test target/arch/hash/size/symlink, stdout/stderr contamination,
  unsupported modes, detached descendants, external writes, residue cleanup,
  root/emulation truth, report bounds, and exit-code preservation.
- Preserve the four native CI rows and exact retained artifact contract.

## Host safety

This Mac is build-only. Do not sign, install, configure, save, enable, or start
a VPN/provider; do not call `startVPNTunnel`; do not alter host routes,
interfaces, packet filters, or DNS. Rootless relay fixtures are allowed only
when isolated and fully cleaned up.

Finish at `to-review` with focused evidence. Do not mark the task done.
