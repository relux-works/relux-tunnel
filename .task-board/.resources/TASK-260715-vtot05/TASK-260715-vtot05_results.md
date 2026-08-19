# TASK-260715-vtot05 independent re-review 06 results

Date: 2026-08-19
Role: reviewer
Verdict: accepted
Route: done

## Acceptance evidence

- AC1 — accepted. The source commit `58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096`, build-recipe commit `4326036a26a515d5d349e669574323d4d1c7259c`, their Git trees/file aggregates, Go 1.26.5 darwin/arm64 archive identity, compiler/internal-linker settings, standard-library-only lock, approved SPDX mappings, exact license hashes, notice obligations, and distribution classes are mutually bound and audit-clean. Independent mutations of every fixed component hash and the relay SPDX mapping all reject. An offline pinned-revision `go list` resolves exactly eight compiled Go files; `relay/go.mod` is the ninth byte-affecting repository input. The extracted Go license SHA-256 is `911f8f5782931320f5b8d1160a76365b83aea6447ee6c04fa6d5591467db9dad`.
- AC2 — accepted. `relay/PRODUCT_NOTICES.txt` deterministically covers the distributed MIT relay source and BSD-3-Clause Go standard library. A missing distributed notice obligation rejects. Twenty-one focused supply-chain tests include missing/mismatched approved metadata coverage.
- AC3 — accepted. Inventory, provenance, notices, asset source/schema, generated Swift catalog, and the exact four-asset archive share manifest linkage `61dbd903ce1055f852a52718adb887d9d5acafb78a6758fae3d0f02a0db9061a`. Independent read-only double rendering matches every checked-in byte. Source URL branch/query/fragment mutations reject. Generated privacy checks reject secret/workstation markers; committed artifacts contain no credentials, private keys, mutable latest URLs, or workstation/temp paths.
- AC4 — accepted. The boundary assigns M2 source pinning and reproducibility to `TASK-260715-27uz4n`, asset integrity to `TASK-260715-1ue4oy`, and notices to this task. The named M5 scopes resolve to concrete backlog work: signing `TASK-260715-3sk5cd`, notarization `TASK-260715-387eof`, release attestation `TASK-260715-1gzhnk`, and distribution approval `TASK-260715-312u2k`.
- AC5 — accepted within the documented bounded contract. The runtime scan fail-closes the exact current `App`, `Sources`, and `relay` surface, supported extensions, exclusions, symlinks/non-regular entries, and unknown future kinds. An independent Clang-backed probe compiled ten fixtures and confirmed rejection for Objective-C URL selectors, Objective-C reflection, Foundation network classes, C process/exec, and libcurl under both `##` and `%:%:`. A safe unrelated paste with forbidden fragments confined to comments/strings compiled and passed. Empty/reordered roots and weakened exclusions reject. The CI job running the audit has `fetch-depth: 0`, `persist-credentials: false`, and the audit command; both historical Git trees resolve in the full repository.

## Commands and real exit codes

- Required `set_status(TASK-260715-vtot05, status=reviewing)`: exit 0.
- Attachment SHA-256 verification: exit 0; every materialized attachment digest matched its supplied digest.
- Independent compiler/audit probe: exit 0; all ten negative fixtures compiled with exit 0 and rejected for the intended reason; safe control compiled and was accepted.
- `make relay-supply-chain-audit relay-supply-chain-test relay-asset-manifest-test`: exit 0; clean audit, 21 supply-chain tests, 26 asset-manifest tests, and four Swift Testing manifest tests passed.
- `make relay-shell-test relay-shell-vet relay-toolchain-check relay-toolchain-negative-test relay-asset-bundle-check`: exit 0; relay packages, 35 release-tool tests, Go vet, missing-input gates, and exact bundle validation passed offline with the pinned toolchain.
- `swift build`, Python compilation, Black 24.8.0 check, recursive Swift format lint, Actionlint, five JSON parses, and `git diff --check`: combined exit 0. Swift emitted only the pre-existing section-alignment warning.
- Offline pinned-revision archive plus Go-list/history/license probe: exit 0; repository reports `is-shallow=false`, both historical trees resolve, and the Go license hash matches.
- Independent authoritative-mutation/privacy/determinism/linkage probe final run: exit 0. Checked-in hashes: inventory `a8c6046067bb5d4296c3022ea18a22031dbc4ed7f6aa91714b9659f703f8ba8f`; provenance `0b17ed44dc56aeff70d28a063af5b7d1f4214f5628f1f4e701829be82d0919e2`; notices `7f1edb1216363e034bd06b4d41edfd04958a597b0dad8ae3cdd4e7c91c69006f`; asset source `8884a4f023e995356b153dedcab8554bc8a4c6ecb445c447c2619b9e1bed4dcc`; generated Swift `f73d6108dba099fe141824083c73bc6d2fd7bc55bdf14feb49f6a672510b9b82`.
- `task-board validate`: exit 0 while reporting one unchanged `PARENT_STATUS_MISMATCH` for `EPIC-260715-2lz67t`, stored `to-dev` versus child aggregate `reviewing`. The epic remains blocked by `EPIC-260715-2mqgvm` and `EPIC-260715-3810we`; validation configuration was not changed and this is not an acceptance defect.

## Reviewer harness anomalies

- The first pinned-source extraction command was rejected before process launch because the scratch command contained recursive deletion. It had no exit code and removed nothing. The safe `mktemp -d` replacement exited 0.
- The first independent contract probe exited 1 after product validation had correctly rejected its mutations because the scratch harness used overly specific expected strings and lacked the repository import path. A second run still exited 1 because two expected strings were swapped. The corrected final probe exited 0. No product file was changed by these scratch-only corrections.

## Safety

No signing, notarization, attestation, publishing, credential or Keychain access, app/provider installation or launch, VPN mutation, `startVPNTunnel`, route/interface/pf/DNS change, external network fetch, or physical validation was performed.
