# TASK-260715-1ue4oy focused rework 06

Resume the current implementation. Fix only the cleanup race proven in `TASK-260715-1ue4oy_reviewer-results-06.md` and regressions introduced by that fix. Do not revisit product graphs, Swift code, archive format, or broad repository state.

## Required cleanup behavior

- Replace `os.lstat(path)` followed by pathname `shutil.rmtree(path)` with descriptor-owned, parent-descriptor-anchored cleanup.
- Open the target with no-follow semantics relative to its parent, verify `fstat` matches the expected `(st_dev, st_ino)`, and traverse/remove children relative to that owned descriptor without reopening the top-level pathname for recursive deletion.
- Never recursively traverse or delete a replacement directory merely because it occupies the former pathname.
- Remove the top-level directory entry only while it still resolves to the expected owned inode; a changed/missing/unsafe entry must fail closed and preserve the replacement.
- Preserve symlink refusal, interruption recovery, atomic publication/rollback, and owned staging semantics.
- Keep cleanup bounded to the known relay bundle tree; reject unsupported entries/types rather than broadening into a general-purpose deletion utility.

## Exact regression

At the former post-identity-check/pre-`rmtree` boundary, move displaced stale A aside and put foreign B with exact marker bytes at the staging pathname. Assert generation fails closed, B's identity and marker survive, A survives aside, and the published bundle is not corrupted. Add focused success coverage for normal owned cleanup and existing symlink/replacement cases.

## Verification

- Run the exact cleanup race, all manifest Python tests, `make relay-asset-manifest-test`, bundle check, Black, py_compile, and `git diff --check`.
- Do not repeat Apple builds or the broad Swift suite for this Python-only delta.
- If Python/Darwin primitives cannot provide the required ownership binding without a compensating race, stop with evidence and propose the simpler fail-closed publication model; do not add unbounded ctypes deletion machinery.
- No signing, install, provider launch, VPN preference mutation, `startVPNTunnel`, or network-state changes.

Attach focused result evidence and route to `to-review`.
