# TASK-260830-1x524u — Shared Runtime Story landing-readiness revalidation

## Verdict

Ready for independent review. The exact Shared Runtime Story candidate passes the configured landing suite and the focused runtime, harness, adapter, macOS target, documentation, diagram, privacy, coverage, negative-gate, and lint checks reproduced by this tester. No product/runtime source was changed by this Task. No VPN/provider was activated and no route, DNS, or NetworkExtension configuration mutation was observed.

## Candidate integrity and dependency terminality

- Exact branch: `task-board/story/STORY-260715-1y04r0` at `9bf4d0892db03035b989a4c040cfee37636ff8df`; a fresh fetch confirms the remote Story ref is identical (`0/0`).
- Exact base: `origin/main` and merge-base are both `b3422b05226253a17676b9b84c764071fe3dbe74`; the Story branch is five commits ahead and zero behind. `git verify-commit` succeeds for all five Story commits.
- Candidate tree: `0ca11378213cc02a78eeac937f94aef6c5209545`; the complete Story delta contains 42 repository paths.
- The Task-owned working delta is limited to `LOGBOOK.md`, `scripts/tests/test-credential-free-validation.sh`, and `task-board.config.json`; it changes validation evidence/configuration and no product source.
- All eleven prior direct Story children are `done`; this Task is the only active child. Direct blockers `STORY-260715-jnpbyz` (packet bridge/HEV), `STORY-260715-lkshfz` (SSH engine), and `TASK-260715-nphtib` (generated macOS architecture verification) are `done`. Both the Task and Story report `isBlocked=false`.

## Freshly reproduced gates

| Gate | Result |
| --- | --- |
| Configured completion command | `LEGACY_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/../relux-proxy" make credential-free-validate`, exit `0`. It includes relay packaging, exact workspace graph, deterministic generation, unsigned macOS host/provider builds and target contracts, Core boundaries, full Swift tests, release build, native packaging, legacy preservation/build/tests, and migration-isolation negatives. |
| Focused Shared Runtime | Eight suites, 105 tests, every suite exit `0`: message codecs, coordinator, provider adapter, VPN session controller, M1 composition, exact macOS ownership, runtime diagnostics, and SSH error mapping. |
| M1 harness | Six production-entry tests plus seven deterministic fixtures, exit `0`. |
| M0 production binding | Permission recomputed `true`; 32 tests covering missing, malformed-as-unknown, narrowed, rebound/forged, dependency-closure, HEV, libssh2, header, patch, and license evidence all pass. |
| Adapters | `ReluxTunnelIOSAdapter` and `ReluxTunnelMacOSAdapter` target builds each exit `0`; this is compile evidence only. |
| macOS target | The fresh configured suite's `macos-target-builds-and-contracts` stage exits `0` for unsigned host/provider generation, builds, and contracts. No signing or provider execution occurs. |
| Full tests and coverage | Fresh `swift test --enable-code-coverage` passes 514 tests in 44 suites with 25 explicitly known-unavailable ReluxNIOSSH cases. Selected Shared Runtime/M1 coverage is `4673/5174 = 90.32%` lines and `1619/1921 = 84.28%` regions; package coverage is `92.91%` lines and `85.22%` regions. |
| Documentation and diagrams | 58 local links in five relevant documents resolve. PlantUML syntax/render succeeds and all four rendered SVG pages are byte-identical to checked-in artefacts. |
| Lint | Swift format, shell syntax, JSON parse, and `git diff --check` all exit `0`. |

## Negative evidence

- Production call site: `scripts/check-workspace-schemes.sh`; production consumer: `scripts/tests/test-credential-free-validation.sh` and the configured validation suite.
- The current test fixture now models the complete active graph, including both UI-test schemes.
- A copied production gate was narrowed by removing only required `ReluxProxyIOSUITests`; the named contract test failed with exit `1` because the otherwise-valid complete graph was rejected. The production file was restored from the copy, verified byte-identical, and the same contract test then passed with exit `0`. The gate was narrowed, not deleted.
- M0 and M1 production-entry tests additionally distinguish absent evidence from unreadable/malformed evidence and reject narrower or caller-rebound claims.

## Provider and system-mutation boundary

- `App/ReluxProxyMacTunnel/Sources/PacketTunnelProvider.swift` was read successfully. A scoped search proves `MacOSProviderCompositionRoot` is absent, while the lifecycle-shell completion paths are present. `docs/m1-runtime-ownership-and-operations.md` documents the same limitation. No live-provider-wiring claim is made.
- Before and after the fresh configured suite, SHA-256 observations for NetworkExtension configuration, DNS state, and full-tunnel IPv4 route selectors were identical; selector row count stayed `2`, Relux process count stayed `0`, and the complete normalized state files compare byte-identical.
- Executed paths were source generation, deterministic CLI harnesses, unit/integration tests, coverage instrumentation, compile/build, unsigned Xcode target validation, lint, diagram rendering, Git/board reads, and read-only system observation. No signing, install, NetworkExtension preference write, `startVPNTunnel`, provider launch, route command, DNS write, or physical VPN gate ran.

## Board anomaly

`task-board validate` returns exit `0` but reports 368 `MISSING_ACTIVITY` records across the wider board. The current Task and Story activity reads succeed and expose `legacy_pre_feature` boundaries plus current events. This outcome reports the wider missing streams as an anomaly; it does not infer a read failure, does not claim global board cleanliness, and does not backfill transaction-owned activity. The scoped dependency, checklist, task/story activity, and status reads required for this handoff succeed.

## Evidence provenance

This tester reran every pass claimed above in the current workspace. Earlier attached pass logs were inspected only for comparison and were not accepted as substitutes. The earlier bounded route-socket monitor remains prior supporting evidence; this run independently captured byte-identical pre/post NetworkExtension, DNS, full-tunnel-selector, and process observations. The earlier CR revision 1 validation failure is preserved as evidence of the stale relative-path call; revision 2 is expected to use the corrected configured command and publish as the derived `story_final` candidate.
