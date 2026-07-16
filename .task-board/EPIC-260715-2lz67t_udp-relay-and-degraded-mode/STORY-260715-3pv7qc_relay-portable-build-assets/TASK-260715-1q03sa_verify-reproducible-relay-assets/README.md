# Verify reproducible relay assets from independent clean builds

## Description
Run at least two independent clean builds per declared target and determine whether the unsigned relay bytes and generated manifest are reproducible, explaining and eliminating uncontrolled drift before bundle consumption.

## Scope
In scope: independent clean workspaces or runners; pinned input comparison; source and toolchain identity; unsigned and unnotarized relay bytes; SHA-256 comparison; section or metadata diff when hashes differ; normalized archive or debug metadata policy; manifest comparison; rebuild procedure; reproducibility evidence and residual variance. Out of scope: signed Apple application archives, notarization tickets, remote installed copies, performance testing, changing protocol behavior, and declaring unexplained nondeterminism acceptable for schedule reasons.

## Acceptance Criteria
1. Two clean builds for each target record identical declared inputs and either identical relay SHA-256 values or a byte-level diagnosis of every difference. 2. Timestamps, paths, build IDs, symbol tables, archive order, locale, and toolchain randomness are controlled or explicitly normalized without altering runtime bytes after manifest hashing. 3. The generated four-entry manifest is byte-identical across clean runs when its input assets are identical and changes deterministically when an asset changes. 4. Any permitted irreducible variance has an approved threat analysis, stable semantic identity rule, and checksum generation from the exact bundled bytes; unexplained variance fails handoff. 5. A TASK-ID-scoped evidence report includes commands, runner identities, input hashes, output hashes, diff method, result, and reproduction steps without sensitive paths or tokens.
