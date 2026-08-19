# TASK-260715-24icoz — focused rework-02 reviewer results

Date: 2026-08-19
Role: reviewer
Verdict: accepted

## Finding disposition

The rework fully closes the predictable temporary-path symlink vulnerability. `write_portable_asset_archive` now creates an exclusive randomized regular file in the archive destination directory with `tempfile.mkstemp`, writes through the returned owned descriptor, records its device/inode identity, atomically replaces the destination, verifies the destination with `follow_symlinks=False`, and cleans up only a still-regular path whose device/inode matches the invocation-owned temporary file.

Independent attack reproductions exited 0 and proved all required boundaries:

- A planted legacy `.<archive>.tmp -> victim` symlink was neither followed, replaced, nor unlinked; the victim SHA-256 remained unchanged.
- The created temporary name was randomized (`.archive.tar.gz.<random>.tmp`), in the destination directory, and a regular file at replacement time.
- A pre-existing final archive symlink was rejected with `portable archive output must be a regular file`; its victim was unchanged.
- On injected `os.replace` failure, a temporary pathname replaced by another actor remained present with its foreign inode/bytes, proving cleanup does not unlink a path it no longer owns.
- The authored command-level regression covers the historical planted symlink, victim integrity, success output, injected replacement failure, and cleanup; the deterministic archive regression covers repeat bytes, extra-file rejection, mode rejection, and exact member metadata.

## Retained artifact and AC evidence

- Fresh board resource download: exit 0. Archive SHA-256 is `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`; size is 4,241,264 bytes.
- Corrected independent archive verifier: exit 0. The gzip payload is USTAR and contains exactly four ordered regular members, mode `0755`, uid/gid `0`, names `root`, integer mtime `1784656987`, empty PAX headers, no AppleDouble members, and exact sizes/hashes. A preliminary reviewer-only assertion typo caused its Python subprocess to exit 1 while the enclosing diagnostic shell continued with exit 0; the corrected verifier then passed and is the reported gate.
- Repeated archive generation: exit 0 and byte-identical SHA-256 above.
- The tar stream contains no serialized xattr/PAX records. macOS attached `com.apple.provenance` to extracted files and an empty control file identically, confirming this is host-injected rather than archive metadata.
- Direct retained-byte inspection with pinned Go 1.26.5: exit 0. Exactly four executables pass format, machine architecture, CPU baseline, minimum runtime, linkage, mode, stripped/no-DWARF disposition, size, and hash checks. Per-asset bytes remain 2,623,664; 2,487,362; 2,592,894; and 2,556,030, totaling 10,259,950 bytes. This measurement remains handed to `TASK-260715-1tzaed`; it is not a shipping-budget policy value.
- Full retained inspector against source commit `58676a23...` and current `HEAD`: exit 1 as required with `source commit does not match checkout HEAD`. Direct byte inspection remained separate and did not convert this provenance mismatch into a pass. The source-revision/clean-checkout functions were not weakened by the diff.
- Native Darwin arm64 identity and protocol-v1 stdio clean-exit smoke: exit 0 as UID 502; canonical identity and exact self-hash matched, stderr was empty, and no runtime files were created.
- Approved Rosetta Darwin amd64 identity and protocol-v1 stdio clean-exit smoke: exit 0 as UID 502 with the same guarantees.
- Linux amd64, Linux arm64, and native Intel execution remain explicitly deferred to `TASK-260715-1c4l9v`, not recorded as passes.
- Targeted privacy scan of the retained executables and task outcome: exit 0 with no developer path, private-key marker, AWS key pattern, or credential match. Declared linkage is limited to the two macOS system libraries; Linux binaries have no `PT_INTERP` or `PT_DYNAMIC`.

## Tests, coverage, lint, and scope

- `make relay-toolchain-test relay-shell-test relay-shell-vet`: exit 0; 35/35 release tests passed twice, every relay Go package passed, and pinned Go vet passed.
- Five focused archive/security/provenance/parser regressions: exit 0. This includes real truncated and wrong-machine ELF/Mach-O parser paths.
- Affected-function standard-library trace coverage: exit 0; 321/396 executable lines, **81.1%**.
- Black, Python compilation, ShellCheck, Actionlint, and `git diff --check`: exit 0.
- Diff inspection found only the task-scoped archive writer, its release tests, the task logbook entry, and board-owned evidence/status changes. No signing, VPN application/provider launch, NetworkExtension preference, `startVPNTunnel`, route, or DNS operation was performed.

All five acceptance criteria and the rework-02 review contract are satisfied. Acceptance evidence is recorded for the commit-owning mover; this reviewer supplies no `commit_ack`.

## Board disposition

- Accepted status transition `reviewing -> done`: exit 0 without `commit_ack`.
- Post-terminal `task-board validate`: exit 0, `Board is valid. No issues found.` The earlier temporary parent aggregation mismatch is resolved.
- `task-board handoff ... --role reviewer`: exit 1 with `role "reviewer" has no end_status and cannot use handoff`. This verdict-driven role routes by its terminal status branch, so the rejected producer-style handoff does not change the accepted `done` disposition.
