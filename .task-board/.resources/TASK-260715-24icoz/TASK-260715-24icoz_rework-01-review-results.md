# TASK-260715-24icoz — focused rework-01 reviewer results

Date: 2026-08-19
Role: reviewer
Verdict: changes requested

## Blocking finding

`write_portable_asset_archive` uses the predictable sibling path `.<archive>.tmp` and opens it with ordinary `Path.open("wb")` without rejecting a pre-existing symlink or creating the file exclusively. An isolated reviewer reproducer pre-created `.archive.tar.gz.tmp -> victim.txt`, then invoked the public `archive-assets` command. The command exited 0, changed the victim SHA-256 from `bd56300ba5f8e2263128ac97c6852ea42770644808a14d54a04113f23200deb6` to the archive SHA-256 `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`, and left `archive.tar.gz` as a symlink to `victim.txt`.

This fails the focused review requirement for safe temporary replacement and means the implementation can overwrite another task-scoped file through a planted temporary symlink. The existing regression test checks deterministic overwrites, extra members, and source mode, but does not cover temporary-path symlinks or require the final output to be a regular non-symlink file.

Required rework:

1. Create the temporary archive atomically in the destination directory with exclusive, no-symlink semantics (or an equivalently safe standard-library temporary-file primitive), and replace only from that owned regular file.
2. Ensure failures cannot unlink or overwrite a pre-existing attacker-controlled temporary path and the final archive is a regular non-symlink file.
3. Add a regression test demonstrating that a planted temporary symlink cannot modify its target and cannot become the final archive.

## Passing evidence retained

- Fresh board download SHA-256: `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`.
- Archive contains exactly four ordered regular USTAR members, mode `0755`, uid/gid `0`, owner/group `root`, integer mtime `1784656987`, empty PAX headers, exact expected sizes/hashes, and no `._*` members. Total executable bytes: `10,259,950`.
- The only extracted xattr was host-injected `com.apple.provenance`; an empty control file created in the same directory received the identical xattr. No xattr/PAX metadata is serialized in the archive.
- Direct retained-byte inspection passes format, machine architecture, CPU baseline, minimum runtime, linkage, debug-symbol disposition, modes, sizes, hashes, and privacy for all four assets.
- The full retained inspector fails closed with exit 1 on source commit `58676a23...` versus current `HEAD`; direct-byte inspection did not convert that provenance mismatch into a pass.
- Native Darwin arm64 and approved Rosetta Darwin amd64 identity plus protocol-v1 stdio clean-exit smokes pass as unprivileged UID 502 with exit 0 and empty stderr. Linux amd64, Linux arm64, and native Intel remain explicitly deferred to `TASK-260715-1c4l9v`, not recorded as passes.
- `make relay-toolchain-test relay-shell-test relay-shell-vet`: exit 0; 34/34 release tests twice, all relay Go tests, and Go vet pass.
- Affected standard-library trace coverage: 300/371 executable lines, 80.9%, exit 0.
- Black, Python compilation, ShellCheck, Actionlint, `git diff --check`, and targeted retained-artifact privacy scan: exit 0.
- No signing, VPN application/provider, NetworkExtension preference, route, or DNS operations were performed.
