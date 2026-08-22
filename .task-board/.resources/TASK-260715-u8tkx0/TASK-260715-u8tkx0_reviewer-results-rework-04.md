# TASK-260715-u8tkx0 fresh reviewer verdict after rework 04

Date: 2026-08-22
Role: reviewer
Verdict: accepted

## Result

Rework 04 closes the final historical default-bundle initial-publication
defect. The documented command now passes the repository-absolute
`.build/relay/relay-assets-v1` destination to both generation and checking.
The task satisfies all five acceptance criteria and the reviewer contract.

## Independent evidence

- A genuine `git clone --no-local --no-hardlinks` began with neither `.temp`
  nor `.build/relay/relay-assets-v1`. The retained archive passed SHA-256 at
  `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`.
- Independent task-scoped bundle generation/check exited `0`. The corrected
  default generation and check commands then exited `0` from an absent
  destination and emitted both expected success tokens.
- The default bundle contained exactly the four canonical executables and
  `relux-relay-assets-v1.json`. Its manifest was byte-identical to the
  independently generated manifest; manifest SHA-256 was
  `bd9428e6de9caa63f659b87d89914be09fe280c1964fbd2064c84af5c9d62614`.
- Producer snapshot inspection proved the rework-04 semantic delta is limited
  to the absolute default bundle variable, explicit generate/check arguments,
  manifest comparison target, truthful task outcome, and one LOGBOOK record.
  Current runbook and LOGBOOK Git object IDs exactly matched the producer
  snapshot. No implementation or coordinated ten-file rotation surface
  changed.
- All five documented `mktemp` calls have explicit parents (`5/5`). Runbook
  shell blocks passed `bash -n` (`14/14`), local links resolved (`32/32`), and
  every concrete board identifier resolved live (`44/44`). The previously
  independently reviewed M2/M5 ownership and ten downstream-consumer mappings
  are unchanged by this focused documentation delta.
- Four focused Python suites passed 107 tests, aggregate exit `0`. Swift
  `RelayAssetManifestTests` passed four tests, exit `0`. Toolchain check,
  supply-chain audit, and accepted trusted-bundle check all exited `0`.
- `make workspace-generate workspace-validate` and
  `make macos-targets-validate` exited `0`. Only the documented product-name
  and multiple-destination warnings appeared; validation remained unsigned
  and build-only.
- Sensitive/host-absolute-path scan and `git diff --check` exited `0`.
  `task-board validate` process exit was `0`; it reported only the expected
  active-parent aggregate mismatch while this task was in `reviewing`.

## Acceptance assessment

- AC1 accepted: a second operator can publish and independently verify the
  historical five-file trusted bundle from a fresh clone.
- AC2 accepted: the strict update order and coordinated ten-surface rotation
  remain unchanged and executable; prior independent evidence retains exact
  `15/15`, native `17/17`, unsupported-runtime rejection, and `10/10` rotation.
- AC3 accepted: rollback retains exact bytes/manifests, distinguishes remote
  coexistence from replacement, and forbids execution before verification.
- AC4 accepted: responsibility separates relay source/hash/notices from
  application signing, notarization, attestation, approval, and M5 ownership.
- AC5 accepted: mismatch, missing target, unsupported runtime, notice failure,
  compromise response, credential-safe evidence, and concrete task ownership
  remain documented and live.

## Safety

The review was rootless and build-only. It did not commit or push, sign,
notarize, attest, publish, install, launch an app/provider, access credentials,
configure or start a VPN, change NetworkExtension preferences, routes, DNS,
interfaces, or packet filters, or execute a mismatched or remote asset.
