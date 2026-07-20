# ReluxNIOSSH rebase procedure

1. Start from a clean disposable worktree. Do not rebase in a product checkout
   with unrelated changes.
2. Record the candidate upstream tag/commit and download its commit archive.
3. Run the conflict preflight against every upstream file currently patched:

   ```sh
   python3 scripts/reluxniossh-fork-tool.py conflict-test \
     --upstream-ref <candidate-tag-or-commit>
   ```

   Exit `0` means none of the patched upstream files changed since the current
   pin. Exit `1` lists the files requiring semantic review; it must not be
   bypassed.
4. Replace the fork tree with the verified candidate archive, preserving its
   license and attribution. Reapply the five logical patches from
   `RELUX_DELTA.md` in order. Never carry an old hunk solely to make a diff apply.
5. Update `UPSTREAM.md` and `PATCH_MANIFEST.json` with the new tag, commit,
   archive/license hashes, dependency pins, and exact changed-file allowlist.
6. Regenerate the upstream patch and inspect every hunk:

   ```sh
   python3 scripts/reluxniossh-fork-tool.py diff \
     --output .temp/TASK-260715-nzdzv3/ReluxNIOSSH-upstream.patch
   ```
7. Run the conflict and validation gates:

   ```sh
   make validate-reluxniossh
   swift format lint --recursive Dependencies/ReluxNIOSSH/Sources \
     Dependencies/ReluxNIOSSH/Tests Dependencies/ReluxNIOSSH/Package.swift
   ```
8. Run the shared E-WINDOW and E-REKEY conformance rows when the adapter suite is
   available. Compare default API behavior and algorithm lists with the new
   upstream before proposing the pin update.

If upstream changes its channel ownership, packet-protection boundary, or KEX
state model such that these patches need compensating flags or duplicated state,
stop the rebase and reassess the fork rather than forcing the old design onto the
new engine.
