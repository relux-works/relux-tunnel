# Verify independent bit-for-bit relay build reproducibility

## Description
Rebuild every relay asset in two isolated environments, compare the bytes and intermediate metadata, and fail release on any unexplained difference.

## Scope
In scope: two clean workspaces or runners, isolated caches, identical pinned inputs, environment capture, raw SHA-256 comparison, binary-section inspection, deterministic archive or strip behavior, diffoscope or approved equivalent diagnostics, repeated-build sampling, and redacted difference reports. Out of scope: accepting signature or timestamp differences in the unsigned relay, weakening compiler hardening for reproducibility, and publishing a nonreproducible exception without approval.

## Acceptance Criteria
1. Two isolated builds for each of the four targets use the same approved input digest set and produce identical unsigned SHA-256 values. 2. The verification proves caches and prior outputs cannot satisfy either build and records runner or container, toolchain, SDK, locale, time, and command identity. 3. Any mismatch produces bounded diagnostics identifying differing sections or metadata without uploading source secrets or entire proprietary environments. 4. Known deterministic-normalization steps are tested independently and no post-build byte patch can conceal a source or toolchain difference. 5. A mismatch blocks manifest generation and release staging until the input or nondeterminism is fixed and the full pair is rerun.
