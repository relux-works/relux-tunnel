# TASK-260715-1ccx3l — Independent review

## Verdict

Changes requested; route to `to-dev`.

The target shells and artifact matrix are technically sound, but release-tool
provenance does not yet implement the accepted toolchain contract.

## Required rework

1. Separate developer Go acquisition from release use. The accepted
   `TASK-260715-3bdplx` decision permits automatic `GOTOOLCHAIN=go1.26.5`
   download for developer setup only; release builds must use a preinstalled,
   checksum-verified official Go 1.26.5 toolchain. The current Make defaults
   resolve Go through `GOTOOLCHAIN=go1.26.5 go env GOROOT`, including for
   `relay-shell-release`, so release mode can auto-acquire the module-cache
   toolchain instead of failing closed on missing release provisioning.
2. Enforce the accepted Syft provenance, not only its displayed version.
   `verify_syft_toolchain` currently accepts any executable whose output
   contains `Version: 1.48.0`. A task-local mock reporting that version with
   `GitCommit: wrong-unapproved-build` passed the verifier. Release/SBOM hooks
   must enforce the accepted Syft 1.48.0 commit and checksum-verified standalone
   input (or an equivalently strong repository tool-manager contract).
3. Add negative tests proving release mode rejects automatic/unprovenanced Go
   acquisition and wrong Syft commit/checksum inputs, then rerun the existing
   matrix and repository validation.

## Passing evidence

- Exact Go 1.26.5 produced all Darwin/Linux amd64/arm64 relay and protocol-test
  artifacts with `CGO_ENABLED=0`, correct target metadata, `-trimpath`, and the
  expected Mach-O/static ELF formats.
- Two builds produced byte-identical pairs for all eight executables and the
  expected SHA-256 values.
- Syft's timestamps and document namespaces changed between scans, so the two
  SBOM hashes and manifests differed. This is explicitly permitted by the
  accepted toolchain decision; each manifest correctly binds its own exact
  SPDX bytes, so this is not a rejection finding.
- Native Darwin arm64 smoke passed. Darwin amd64 passed only under Rosetta and
  remains labelled as a native Intel release-CI gate. Both Linux runtime rows
  remain native release-CI gates rather than local passes.
- Smoke output is deterministic and contains only executable version, protocol
  version, source revision, target, the empty-health contract, and an explicit
  `relayBehaviorImplemented: false` field.
- The runnable protocol-test target covers only empty health plus one protocol
  version mismatch. No new socket, UDP association, framing, deployment, SSH,
  or publication behavior was added by this task.
- Strict manifest/checksum verification, SPDX 2.3 package policy, Go/repository
  notices, Apple-bundle input, dirty-checkout rejection, and source-revision
  validation passed.
- Pinned Go unit and race tests, Go vet, Python tests/compile, ShellCheck,
  protocol parity and regeneration, 57 Swift protocol tests, Swift build,
  `git diff --check`, and board validation passed.
- Changed/untracked versionable files contain no absolute local path,
  credential pattern, or raw spawn-log artifact. The board runner's automatic
  reviewer log resource was removed under the task privacy rule.

## Re-review gate

Re-run the full four-target two-build comparison, smoke matrix, manifest/SBOM
verification, release negative tests, Go tests/race/vet, protocol check,
ShellCheck, diff check, privacy scan, and board validation after provenance
enforcement is added.
