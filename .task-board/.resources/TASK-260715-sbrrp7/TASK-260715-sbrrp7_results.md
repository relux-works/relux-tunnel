# TASK-260715-sbrrp7 developer rework results

Status: READY FOR REVIEW.

## Reviewer blocker resolved

The macOS PR job now pairs the arm64 `macos-15` runner with the published Mise v2026.3.10 macOS arm64 SHA-256 `c7a0eb1035de974b42d36b69c4b55b836c06b455b990dd6ac530aaf05d4a8a17`. The validation contract asserts the exact runner label, pinned action commit, version, architecture-labelled checksum, ordering, and single repository Make entry point. Documentation and LOGBOOK.md describe the arm64 pairing. Verified against the official actions/runner-images table, pinned mise-action source, and Mise v2026.3.10 SHASUMS256.txt.

## Validation evidence

- `make credential-free-validate LEGACY_ROOT=/Users/iv/Developer/relux-proxy`: exit 0.
- Passed: checksum-pinned relay bootstrap; validation contract regressions; deterministic generation; exact active/deferred target and scheme graph; unsigned Debug/Release host and provider builds; entitlement, embedding, architecture, and linkage inspection; core boundaries; shared Swift tests; Swift Release build; native packaging; relay shell smoke; isolated pinned v0.1.0 legacy preservation, tests, and Release build.
- Swift Testing: 443 tests in 37 suites passed; 25 intentional known issues reported.
- Explicit NOT RUN: production signing, physical Gate P0, Developer ID archive, notarization, and DMG publication require credentials or downstream release gates.
- Explicit NOT RUN: deferred ReluxProxyIOS and ReluxProxyIOSTunnel remain absent per ADR-024/ADR-027.
- `./scripts/tests/test-credential-free-validation.sh`: exit 0.
- `sh -n` for all changed shell scripts: exit 0.
- ShellCheck for all changed shell scripts: exit 0.
- workflow YAML parse: exit 0.
- `git diff --check`: exit 0.
- `task-board validate`: exit 0, no issues.

## Privacy-safe artifacts

The gate writes only under `.temp/TASK-260715-sbrrp7/credential-free-validation/`. `summary.log` records every invoked lane and result. `environment.log` records source revision `9b97a547d56dec40c9f550da783ffde45ef401a8`, source epoch, clean/dirty state, host architecture, public tool versions, SDK inventory, deployment targets, and invoked schemes; it does not dump the process environment, secrets, or signing inputs. Logs are split per lane below the task-scoped `logs/` directory.

## Local and CI entry points

The documented clean-checkout command is `make credential-free-validate LEGACY_ROOT=/path/to/relux-proxy`. The macOS PR workflow bootstraps only the pinned Mise runner dependency, then invokes that same Make target without duplicating repository validation policy.