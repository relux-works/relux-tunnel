# Implement safe remote checksum verification fallbacks

## Description
Verify the exact remote temporary-file bytes against the trusted manifest SHA-256 before execution, preferring allowlisted hash utilities and using a bounded readback-and-local-hash fallback when they are unavailable.

## Scope
In scope: expected hash from bundled manifest; sha256sum and shasum -a 256 fixed commands; strict one-record output parsing; file size check; bounded binary readback over exec and local SHA-256 fallback; timeout, cancellation, utility absence, nonzero exit, malformed output, mismatch, and cleanup; self-hash only as secondary post-verification identity evidence. Out of scope: accepting remote-provided expected hashes, executing an unverified file as the sole verification method, downloading utilities, weak hashes, GPG trust setup, final atomic rename, and remote host trust beyond authenticated SSH.

## Acceptance Criteria
1. Verification compares size and SHA-256 against the locally trusted manifest and accepts only an exact normalized 64-hex digest for the exact quoted temporary path. 2. sha256sum and shasum paths use fixed allowlisted commands and reject extra records, alternate paths, control characters, truncation, timeout, nonzero exit, and ambiguous or remotely supplied expectations. 3. When utilities are absent, the client reads the file back through a bounded authenticated exec stream and computes SHA-256 locally before any chmod-to-execute or launch; mismatch never executes. 4. Protocol self-hash may confirm build identity only after independent byte verification and cannot be the sole pre-execution trust check. 5. Tests cover both utilities, utility absence, hostile output, same-size corruption, truncation, growth, readback stall, cancellation, and known mismatch with deterministic removal and privacy-safe reason codes.
