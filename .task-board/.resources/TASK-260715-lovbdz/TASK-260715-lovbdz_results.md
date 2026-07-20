# TASK-260715-lovbdz implementation and verification

Date: 2026-07-20
Role: developer

## Implementation

- Added candidate-neutral protocol/schema v1 models and sorted-key JSON codecs for:
  - non-secret provider configuration references and start requests;
  - immutable configuration snapshots;
  - four read-only commands and protocol capability discovery;
  - capability, lifecycle, diagnostics, and protocol-error snapshots;
  - runtime generation/sequence ordering.
- Enforced the accepted 4 KiB, 16 KiB, and 64 KiB family limits on encode and decode.
- Added strict bounded JSON preflight for UTF-8, object root, duplicate keys, 16-level depth, JSON number grammar, complete syntax, and trailing bytes.
- Preserved exact legacy v1 `version` request/response bytes and rejected forbidden additive fields.
- Replaced the shared runtime arbitrary string-parameter dictionary with UUID-backed profile, profile-revision, credential, trust, and request identifiers. Harness-only experiment parameters remain outside runtime configuration.
- Added fail-safe output projection: unknown lifecycle/route values set every capability false. No M2 full-mode field exists.
- Added DocC model/version/required-field/default/size documentation and updated the package overview and README.
- Recorded the structural secret-exclusion decision in `LOGBOOK.md`.

## Tests

Added deterministic Swift Testing fixtures and cases for all model round trips, golden output, unknown fields, old/future protocol and schema versions, unknown input kinds/values, invalid UTF-8, duplicate and escape-equivalent keys, corrupt/trailing JSON and numbers, excessive nesting, missing required fields, oversize encode/decode, UUID secret-shape rejection, independent capabilities, fail-safe unknown output projection, redacted finite error codes, snapshot ordering, and exact legacy compatibility.

## Verification

- `swift format lint --recursive Sources Tests Package.swift` — passed with no diagnostics.
- `make validate-core` — passed:
  - core dependency/import boundary guard passed;
  - native fixture and ReluxLibSSH2 packaging verification passed;
  - 182 Swift tests in 21 suites passed;
  - post-test `swift build` passed for core, native adapter, iOS adapter, macOS adapter, harness support, and harness.
- `git diff --check` — passed.

The linker emitted the repository's existing section-alignment warning while linking test/harness binaries; it did not fail any build or test.
