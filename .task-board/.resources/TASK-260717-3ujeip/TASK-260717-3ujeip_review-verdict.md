# TASK-260717-3ujeip independent review verdict

Verdict: accepted. Route: done.

## Acceptance evidence

- AC 1: The maintained threat model covers macOS-first assets, ten data flows, trust boundaries, nine adversary classes, mitigation states, residual risks, abuse boundaries, non-goals, and change-control triggers.
- AC 2: The separate security claims source contains approved and prohibited wording and preserves SSH visibility and fingerprintability, exit-host destination and plaintext visibility, no baseline Relux traffic path, and platform-scoped rather than absolute fail-closed semantics.
- AC 3: All fourteen approved claims have source, implementation evidence, and a residual gate. Host verification is contract-only; Keychain and DNS are planned; fail-closed, degraded mode, and Sparkle remain release-gated; component tests are not generalized into a shipped VPN claim.
- AC 4: Named specs and accepted ADRs are consistent with the evidence states. No secrets, user traffic, machine paths, local usernames, literal endpoints, or credentials were found in the scoped artifacts. Local links, table widths, claim IDs, whitespace, and board structure validate.
- AC 5: The producer outcome records changed files, claim crosswalk, validation commands, residual gates, and the three linked downstream consumers. This resource is the distinct independent reviewer verdict.

## Independent implementation checks

- SSH host acceptance is a typed prerequisite to credential lookup; production SSH selection remains backlog and is not claimed shipped.
- No production Keychain vault or resolver exists; the claim is planned and prohibited as current behavior.
- The coordinator admits compatible mode only, requires injected safe DNS before settings, revokes capability before cleanup, and never claims production route or DNS evidence.
- The internal SOCKS boundary is loopback-only, per-run authenticated, and bounded, while the docs retain the local-process residual risk.
- The relay CLI and stdio component start no listener, daemon, or child process; the product transport exposes exec/stdin upload without an SFTP surface, while remote deployment and UDP composition remain gated.
- Runtime diagnostics expose finite aggregate schemas and reject unreviewed destination-like fields.
- No Sparkle or appcast implementation exists; ADR-018 is represented only as accepted future design.

## Validation rerun

- make validate-core: passed, including 332 Swift tests in 29 suites and post-test build.
- make relay-protocol-check: passed, including 89 vectors, Go protocol tests, 58 Swift tests in 7 suites, regeneration and drift checks, and build.
- Independent spec link, Markdown table, and SC-01 through SC-14 crosswalk audit: passed across all 15 spec Markdown files.
- Scoped privacy pattern scan: passed.
- git diff --check: passed.
- task-board validate: passed with no issues.
- Board queries confirmed TASK-260717-3ujeip blocks the three documented downstream consumers.

## Residual gates

Residual release gates remain as documented and are not review defects: selected production SSH, Keychain/profile/trust storage, authoritative DNS policy and composition, physical route/DNS/fail-closed evidence, relay deployment and frame-pump composition, full/degraded recovery, support export privacy, application release CI, Sparkle/appcast/signing/notarization/rollback, and external approval or audit.
