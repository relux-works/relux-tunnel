# TASK-260715-d6x51z handoff evidence

## Documentation outcome

Updated `docs/generated-workspace-foundation.md` as the canonical clean-checkout developer workflow and linked it from `README.md`. Corrected the generated v2 versus legacy v0.1.0 baseline in `CONTRIBUTING.md`, and added the task entry to `LOGBOOK.md`.

The workflow covers exact pinned prerequisites and commands; generated versus edited files; all six macOS schemes; four generated targets; shared Swift package, relay, and native ownership; unsigned generation/build/test and harness/relay/legacy validation; non-secret Gate P0 identifiers and local credential boundaries; dependency updates; artifact and log locations; troubleshooting; legacy coexistence; migration non-goals; and implemented/build-tested versus unperformed signed physical-VPN and release validation.

The target-ownership table contains 21 rows: four generated targets, fifteen SwiftPM targets, and two relay executables. Each row identifies sources, tests, responsible module, allowed dependencies, and applicable specifications.

## Original verification accepted by independent review

At source revision `d18847cd6d7f3b84bdd807eddbca37d9259945de`, the credential-free clean-checkout matrix exited 0. It covered checksum-pinned relay bootstrap and packaging, deterministic generation, unsigned Debug and Release macOS host/provider builds, generated target contracts, core boundaries, the complete shared Swift test suite, Swift Release build, native packaging, and detached legacy v0.1.0 preservation, guards, tests, and Release build.

The independent reviewer also accepted the command/path evidence, all 21 ownership rows, six active schemes, Debug/Release claims, local Markdown links, architecture diagram parsing, command-contract tests, 13 harness tests, inline harness smoke with profile redaction, diff hygiene, secret-boundary scans, and board validation. The only requested rework was cross-document signing-boundary consistency.

## Reviewer-requested rework

Resolved the blocking discrepancy without changing the accepted workflow or ownership content:

- `README.md` now labels the signed Gate P0 probe command dedicated-host-only, explicitly prohibits signing and probe execution on this build host, and links the safety policy.
- `docs/build-host-safety.md` now explicitly prohibits product code signing and running the signed Gate P0 probe, including `build-and-inspect.sh`, on this host.
- `CONTRIBUTING.md` now carries the same product-signing and probe prohibition while distinguishing it from the repository requirement for signed Git commits.

Focused rework validation:

- local Markdown link validation: exit 0, all local links resolve;
- fenced-example credential/signing/network-mutation scan: exit 0;
- documentation-delta credential-payload/private-signing-path scan: exit 0;
- `git diff --check`: exit 0;
- `./scripts/tests/test-credential-free-validation.sh`: exit 0;
- `task-board validate`: exit 0, no issues found.

Per the rework contract, the full credential-free build matrix was not rerun.

## Safety and exclusions

No signing, credential inspection, installation, app/provider launch, VPN preference save or activation, route mutation, or DNS mutation occurred during this rework. Production signing, physical Gate P0, Developer ID archive, notarization, DMG publication, iOS, physical VPN behavior, and release validation remain explicitly NOT RUN and are not shipping claims. Dedicated-host work remains gated by `TASK-260819-25e1ys`.
