# TASK-260715-u8tkx0 build-only runbook contract

Publish an operator-grade relay asset release/update/rollback runbook derived
from the accepted `vtot05`, `mocqmr`, and `1q03sa` implementations. The runbook
must be executable by a second authorized developer without tribal knowledge.

## Required content

- Exact prerequisites and pinned identities for Go, Syft, source revision,
  recipe/provenance manifests, environment normalization, and four targets.
- Copy/paste-safe commands for clean build, supply-chain/license audit,
  manifest/checksum/notices generation, exact tree verification,
  reproducibility, native runtime smoke, bundle integration, and downstream
  bootstrap validation. State the expected success tokens and red conditions.
- A strict update sequence: source/dependency/security review; protocol/schema
  compatibility; toolchain pin review; build; notices/SBOM/provenance; exact
  manifest/checksums; two-clean-build reproducibility; four native runner smoke;
  Apple bundle-input validation; bootstrap consumer tests; only then release.
- Rollback using a retained known-good manifest plus exact bytes. Cover remote
  version coexistence/replacement, fail-closed mismatch handling, and the rule
  that no downloaded/remote asset executes before local exact hash/manifest
  verification.
- Incident procedures for hash drift, missing target, unsupported native
  runner, notice/SBOM/provenance failure, bundle mismatch, suspected compromised
  asset/tool/source, and credential-safe evidence collection. Include containment,
  revocation/rotation, rebuild, consumer verification, and escalation boundaries.
- A responsibility/RACI-style table separating relay source and dependency
  integrity, reproducible bytes, bundle hashes, notices, application signing,
  notarization, attestation, release approval, and remote bootstrap ownership.
- Explicit M2-vs-M5 boundary and concrete task IDs for every build gate and every
  downstream bootstrap/bundle consumer. Discover IDs from the live board and
  verify titles/statuses; do not invent or use container-only references.
- Clearly state that relay executables are not standalone signed downloads: the
  containing signed/notarized app protects bundled assets, and remote execution
  still requires exact manifest/hash verification.

## Verification

- Perform a clean-room operator walkthrough using only the draft runbook and
  repository state. Record exact commands and outcomes in a bounded, path-free
  task outcome.
- Validate all task links, commands, filenames, expected outputs, and ordering
  against the current Makefile/scripts/schemas/docs. Broken or aspirational
  commands must be labeled future gates, not presented as working.
- Run documentation/link checks plus the focused supply-chain,
  reproducibility, runtime-smoke, and bundle-input verification commands needed
  to prove the runbook is executable. Do not claim remote CI rows ran locally.

## Host and git safety

This Mac is permanently build-only. Do not sign/notarize, install, configure,
save, enable, or start an app/provider/VPN; do not call `startVPNTunnel`; do not
mutate routes, interfaces, packet filters, or DNS. Rootless offline build and
relay fixture commands are allowed with complete cleanup.

Do not commit or push. Finish at `to-review`; the orchestrator owns independent
review and git hygiene.
