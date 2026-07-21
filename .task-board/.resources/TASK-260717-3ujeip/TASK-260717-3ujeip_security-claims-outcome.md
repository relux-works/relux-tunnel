# TASK-260717-3ujeip threat-model and security-claims outcome

Producer handoff: ready for independent review.

## Changed documentation

- `.spec/threat-model.md` — replaced the seed with the macOS-first v1 threat
  model covering evidence states, assets, ten data flows, nine trust/adversary
  boundaries, a mitigation ledger, does-hide matrix, platform-scoped
  fail-closed semantics, abuse boundaries, non-goals, residual risks, and change
  triggers.
- `.spec/security-claims.md` — added the shippable claims source with fourteen
  approved claims, sixteen prohibited claims, observer wording, implementation
  crosswalk, release evidence gates, and downstream consumer rules.
- `.spec/README.md` — indexed both security documents and corrected the
  all-unimplemented statement to the current partial-component state.
- `LOGBOOK.md` — recorded the evidence-boundary decision and residual release
  gates.

## Claim crosswalk summary

| Claims | Evidence result | Main residual gate |
| --- | --- | --- |
| SC-01, SC-02, SC-14 | Accepted exit/SSH design; no shipped VPN claim | Concrete provider, selected SSH adapter, and physical route/DNS/exit evidence |
| SC-03 | Mandatory exit-host disclosure | Preserve destination, resolver, and plaintext visibility wording |
| SC-04 | Host-key-before-credential contract and tests | Production SSH adapter, trust repository/UI, lane consistency, physical auth evidence |
| SC-05 | Keychain-only persistence is planned/unverified | Credential vault, extension resolver, access groups, archive and security tests |
| SC-06 | Packet and relay bounds have component tests | Selected SSH parser and composed hostile-input/soak evidence |
| SC-07 | Tunnel-owned fail-safe DNS is planned/evidence-gated | Proposed ADR-022, authorized runtime limits, production DNS/routes, leak tests |
| SC-08 | Platform-scoped fail-closed is accepted design | Current coordinator is compatible-only; implement settings/lifecycle and test OS exceptions |
| SC-09 | Authenticated loopback SOCKS component is implemented | Preserve local-process residual risk and validate provider composition |
| SC-10 | Rootless stdio/no-listener relay components and no-SFTP product contract | Remote install/upload, SSH frame pump, stdio-to-UDP composition, release asset verification |
| SC-11 | Full/degraded mode is accepted design | Capability controller, UDP rejection/restoration, physical full/degraded tests |
| SC-12 | Finite aggregate diagnostics exist; no baseline vendor traffic service is specified | Release endpoint/dependency/log scan and support-export privacy gates |
| SC-13 | Signed/notarized macOS update is accepted design only | Sparkle/appcast/release jobs, key custody, rollback, withdrawal, integrity tests |

The full source/spec/code mapping is in `.spec/security-claims.md` section 5.

## Validation evidence

- `make validate-core` — passed core/native boundary checks, 332 Swift tests in
  29 suites, and the post-test build.
- `make relay-protocol-check` — passed 89 canonical vectors, Go protocol tests,
  58 Swift protocol tests in 7 suites, schema/negative-fixture regeneration and
  drift checks, and the build.
- Local Markdown reference/table audit — checked all 15 `.spec` Markdown files;
  every local link resolves and every contiguous table has a consistent column
  count.
- Scoped privacy/secret audit — changed security documents and this task's new
  logbook entry contain no machine paths, local usernames, email addresses,
  credentials, key material, host literals, or traffic samples.
- `git diff --check` — passed.
- `task-board validate` — passed with no board issues.
- Board query confirmed this task blocks the three named downstream consumers.

## Residual evidence gates

- Production SSH selection remains open under `TASK-260715-1gjxer`; candidate
  adapters are not accepted release evidence.
- DNS runtime policy remains non-authoritative and blocked under
  `TASK-260721-3miqh4`; ADR-022 remains Proposed.
- Profile/Keychain/trust repositories, production route/DNS composition,
  platform fail-closed settings, physical leak matrices, relay deployment and
  SSH composition, full/degraded recovery, support export, application release
  CI, Sparkle, appcast, signing/notarization, rollback, and key-custody evidence
  remain open.
- No independent security audit, external penetration test, legal approval,
  entitlement acceptance, or App Store approval is claimed.

## Downstream consumers

- `TASK-260715-6qqmsz` — VPN privacy disclosure and zero-telemetry UI.
- `TASK-260715-2gwfaw` — VPN privacy, retention, and support copy.
- `TASK-260715-2k812u` — versioned public VPN privacy policy.

Each consumer must preserve the security claim ID and evidence state and must
not promote planned behavior to a shipped claim.
