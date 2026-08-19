# TASK-260715-24icoz — safe temporary archive replacement rework

Date: 2026-08-19
Role: developer
Disposition: ready for review

## Rework outcome

- Replaced the predictable sibling `.<archive>.tmp` with `tempfile.mkstemp` in the destination directory. Creation is atomic and exclusive, returns an already-open regular-file descriptor, and does not follow a planted path.
- Cleanup is ownership-aware: the writer records the created file's device and inode and unlinks only a still-regular path with that exact identity. It never removes the planted legacy symlink. The final destination is checked with `follow_symlinks=False` after `os.replace` and must be a regular non-symlink file.
- Added a command-level `archive-assets` regression that plants the former predictable temp symlink to a victim, proves the victim hash and planted symlink remain unchanged, verifies the final archive's exact four-member metadata/size/hash contract, injects replacement failure, and proves only the invocation-owned randomized temp file is cleaned.
- Source-revision mismatch and clean-checkout provenance behavior remain unchanged and pass focused tests.

## Retained archive

The four previously verified canonical executable bytes were repackaged and updated through `task-board resource update`. Fresh board download SHA-256 is `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`, byte-identical to the prior deterministic archive.

| Member | Bytes | SHA-256 |
| --- | ---: | --- |
| `darwin-amd64/relux-relay-darwin-amd64` | 2,623,664 | `783b94982e90f0ceed0af0fa11662d11a333e244b87256cbfa0f7d21695f3290` |
| `darwin-arm64/relux-relay-darwin-arm64` | 2,487,362 | `8ac45b257099c9d2079b0bd2cb9ae489acfb86e443ba7ca7e4b4b2a56380d64c` |
| `linux-amd64/relux-relay-linux-amd64` | 2,592,894 | `ddcb22ed4d4a978992a04096abae8adc58d0b8bf3bcdc0c0a006775797e2941f` |
| `linux-arm64/relux-relay-linux-arm64` | 2,556,030 | `908b3d9ea3543b6144e2c99407c9aa02cc69e86c1cce80364d32dbdc3de8e0dc` |

Total executable bytes remain **10,259,950**, already handed to `TASK-260715-1tzaed` as measurement evidence, not a shipping-policy value. The board-downloaded archive contains exactly four ordered regular USTAR members with mode `0755`, uid/gid `0`, root names, integer mtime `1784656987`, empty PAX headers, exact sizes/hashes, and no AppleDouble members. The targeted privacy scan found no developer paths, private-key markers, or AWS access-key patterns.

## Runtime and deferred rows

- Native Darwin arm64 identity and protocol-v1 stdio clean-exit smoke: exit 0 as unprivileged UID 502; canonical identity/self-hash matched; stderr empty.
- Approved Rosetta Darwin amd64 identity and protocol-v1 stdio clean-exit smoke: exit 0 as unprivileged UID 502; canonical identity/self-hash matched; stderr empty.
- Linux amd64, Linux arm64, and native Intel execution remain explicitly deferred to `TASK-260715-1c4l9v`, not recorded as passes.

## Validation

- `make relay-toolchain-test relay-shell-test relay-shell-vet`: exit 0; 35/35 release tests passed twice, all relay Go tests passed, and Go vet passed.
- Post-format focused release suite: exit 0; 35/35 tests.
- Affected-function standard-library trace coverage: exit 0; 316/389 executable lines, **81.2%**.
- Focused source-revision mismatch and clean-checkout tests: exit 0. An initial mistyped unittest selector exited 1 with `AttributeError`; the correct named tests then passed.
- Black initially exited 1 for formatting drift in the new test; Black was applied, then Black check, Python compilation, ShellCheck, Actionlint, and `git diff --check` all exited 0.
- Fresh board download byte comparison, archive contract, and privacy scan: exit 0.

No signing, VPN application/provider launch, NetworkExtension preference, route, or DNS operation was performed.
