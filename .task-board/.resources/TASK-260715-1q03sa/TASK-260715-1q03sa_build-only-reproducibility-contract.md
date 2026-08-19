# TASK-260715-1q03sa build-only reproducibility contract

Prove reproducibility for the exact accepted relay build and runtime-gate
contract at commit `e8bd954a1985e0a3204504209f1b022f71e4d1f9`.

## Required implementation and evidence

- Perform at least two genuinely independent clean builds of all four declared
  targets (`darwin/amd64`, `darwin/arm64`, `linux/amd64`, `linux/arm64`). Use
  separate `mktemp -d` workspaces or equivalent isolated copies; do not clean,
  reset, or overwrite the shared repository worktree.
- Pin and record source tree/file identities, Go 1.26.5, Syft 1.48.0, environment
  normalization, target, build command, `SOURCE_DATE_EPOCH`, locale/timezone,
  and relevant linker flags. Evidence must contain semantic labels and hashes,
  never local absolute paths or tokens.
- Compare every executable and its SPDX SBOM, manifest, checksum file, notices,
  and any bundle-input metadata byte-for-byte and by SHA-256. If bytes differ,
  diagnose with format-aware and raw byte offsets; unexplained variance is a
  red handoff, never an accepted exception.
- Prove the four-entry manifest is byte-identical for identical exact inputs and
  changes deterministically when one copied asset is mutated. The mutation must
  never alter or replace the canonical accepted artifact.
- Preserve the accepted supply-chain/runtime contracts from `1ue4oy`, `vtot05`,
  and `mocqmr`; do not weaken manifest hashing, exact-bundled-byte identity,
  native CI rows, or runtime containment to make reproducibility pass.
- Add or improve repository-local automation and regression tests where the
  proof is not already durable. Attach a TASK-scoped bounded, path-free report
  containing exact commands, input/output hashes, comparison methods, runner
  identity, result, and reproduction steps.

## Host and git safety

This Mac is build-only. Do not sign/notarize, install, configure, save, enable,
or start an app/provider/VPN; do not call `startVPNTunnel`; do not mutate routes,
interfaces, packet filters, or DNS. Rootless local build/smoke subprocesses are
allowed only within isolated workspaces with complete cleanup.

Do not commit or push. Finish at `to-review` with all task checklist items and
producer DoD complete. The orchestrator owns review and git hygiene.
