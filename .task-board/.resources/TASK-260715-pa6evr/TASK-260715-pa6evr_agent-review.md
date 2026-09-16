# Independent draft review — TASK-260715-pa6evr

Verdict: ACCEPT

Reviewed document: `docs/TASK-260715-pa6evr_relay-release-input-contract.md`

Reviewed SHA-256: `0c2ecaf408bad5ea486a74752fc50c98ed5c0ce1a178764508aa42027521356f`

This is independent agent acceptance of the developer-contract draft before producer handoff. It is not canonical Change Request acceptance, human ratification, release certification, or permission to publish. The orchestrator owns canonical review and delivery.

## Findings and disposition

1. Resolved: the original input lock pinned the exception-set digest while exception entries bound the input-lock hash, creating a hash cycle for nonempty exceptions. Section 2.2 now freezes inputs first, binds exception decisions downstream, and pins their exact bytes in the staging index. Section 5.3 retains exact-subject scope and independent approvals. No circular identity is required.
2. Resolved: the original deterministic archive membership was unspecified even though staging includes genuine run IDs and timestamps. Section 4 now limits the deterministic archive to exactly the 11 `release/` members, preserves the existing 15-file comparison (including four protocol-test binaries), verifies the input-lock digest separately, and requires bundled executable copies to equal reproduced bytes. Attempt-dependent staging records remain fully inventoried and hash-verified without a false reproducibility claim. No scan, approval, dependency, license, or executable substance is normalized away.
3. No remaining blocking findings. Exact historical source/recipe/tool/archive authorities are distinguished from missing M5 runner, auxiliary tool, scanner, and advisory pins. Missing materialization has named owners and blocks certification. Four target triples, names, execution/identity/layout boundaries, isolated-build requirements, normalization rationales and tests, artifact schemas, consumers, staging protection, retention and exception policy are specified. Human ratification is explicitly consolidated in TASK-260717-2d308k; downstream implementation may proceed after agent draft acceptance. Linux native release evidence remains required for four-target certification without becoming a working-client prerequisite.

## Evidence inspected

- Entire reviewed draft, including both corrected passages and final hash.
- `.spec/delivery.md` and `.temp/TASK-260715-pa6evr/ci-contract.md`, especially release/review, relay staging, immutable candidate authority, Linux deferral, and retention.
- `relay/toolchain-manifest-v1.json`, `relay/supply-chain-source-v1.json`, `relay/asset-bundle-source-v1.json`, `relay/manifest-v1.schema.json`, and `relay/asset-manifest-v1.schema.json`.
- `scripts/relay_release.py`: target constants, SPDX normalization/generation, exact tree/mode/byte comparison, and `compare_release` production entry.
- `scripts/tests/test_relay_release.py`: existing normalization and comparison cases. The normalizer changes namespace/time and JSON serialization; it does not delete or reorder component/relationship arrays.
- `scripts/relay_asset_manifest.py`: provenance validation, archive authority, and consumer verification; `scripts/relay_supply_chain.py`: source checks and acyclic manifest linkage projection.
- `relay/cmd/relux-relay/main.go`, `relay/internal/buildinfo/identity.go`, and `docs/relay-asset-release-runbook.md`.
- README and UNRESOLVED_QUESTIONS links to this contract and deferred ratification.
- Producer logs `pin-reconciliation-01.log` (9 source files, 3 recipe files, 8 archive hashes, four target rows) and `normalization-tests-01.log` (six passing existing tests).

## Limits

Read-only source review; no builds, provisioning, native execution, VPN, signing, remote installation, secret access, board mutation, commits, or publication performed. Producer test/pin logs were inspected, not independently rerun. No new implementation tests are warranted solely for this prose delta. Downstream schema validators, immutable runner/scanner materialization, two independent builds, native certification, and archive metamorphic tests remain explicit implementation obligations. No human approval or landed-code status is inferred from accepted draft evidence.
