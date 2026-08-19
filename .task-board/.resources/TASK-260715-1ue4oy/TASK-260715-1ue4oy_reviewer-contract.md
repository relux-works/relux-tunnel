# TASK-260715-1ue4oy independent review contract

Perform a fresh adversarial review of the relay asset manifest implementation and the accompanying execution-policy alignment. Do not trust the producer report without reproducing the load-bearing claims.

Required review:

1. Verify the generator consumes the accepted `TASK-260715-24icoz` archive (SHA-256 `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`) and never silently substitutes current checkout or `.build/relay/apple-bundle-input` bytes.
2. Recompute archive/member sizes and hashes. Verify exactly four canonical executable members, stable ordering, schema/protocol/build identity/provenance, canonical manifest bytes, deterministic regeneration, and fail-closed handling of missing, extra, renamed, duplicate, zero-length, hash/identity/protocol/schema mismatches, unsafe paths/symlinks, unparseable data, stale generated Swift, and unexpected bundle files.
3. Audit bounded-memory/path safety and replacement semantics. Look for archive traversal, symlink following, mutable caller path injection, unchecked allocation/JSON growth, TOCTOU, partial-output residue, or network access.
4. Verify `RelayAssetCatalog.bundled` is immutable and typed, normalizes only documented Darwin/macOS/Linux and x86_64/amd64/aarch64/arm64 values, resolves only `Bundle.main` resources, and exposes no mutable manifest or caller-supplied filesystem path.
5. Independently build/test both SwiftPM Apple adapter graphs and the unsigned generated macOS host/provider products. Verify the built provider contains exactly the validated manifest/four assets and that both product graphs compile the lookup. Do not sign, install, launch, or approve the app/provider.
6. Run the manifest Python/Swift tests, bundle drift check, provider-graph negatives, protocol/core-boundary checks, formatting/syntax/privacy checks, and inspect the diff for unrelated changes.
7. Investigate the two reported broad-suite HEV UDP timing failures. Determine from diff and focused reproduction whether this task caused a regression. Do not hide failures: if task-caused, request changes; if demonstrably pre-existing/out-of-scope flakiness, require durable evidence/tracking and state the broad suite remains non-green.
8. Verify `task-board.config.json`, `docs/spawn-policy.md`, and `.spec/goal-macos-v1.md` consistently enforce Codex `gpt-5.6-sol` high, Codex-only provider selection, fresh Codex review, and `max_parallel: 1`.

Build-host safety is mandatory: no signing, install, approval, application/provider launch, `startVPNTunnel`, NetworkExtension preference mutation, routes, DNS, or real VPN state. Builds, generated-workspace inspection, rootless relay executions, and harness tests are allowed.

Return an explicit accepted or changes-requested verdict with task-scoped evidence. Never stop at reviewing.
