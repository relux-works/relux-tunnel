# TASK-260720-100wu6 — Review verdict: ACCEPTED

Reviewer: [reviewer] reviewer (claude), 2026-07-20

## Verification performed (re-run independently, not just log inspection)

- `make validate-core`: boundary script (incl. new SSH candidate-name grep), package
  dependency-shape check, 61 tests in 8 suites, `swift build` — all passed.
- `swift test --filter SSHTransportContractTests`: 12/12 passed.
- `swift format lint --strict` on SSHContracts.swift, SSHTransportContractTests.swift,
  HarnessTests.swift: clean.
- Grep for stale skeleton types (`SSHProfile`, `SSHTransportMetrics`): none remain.

## AC assessment

1. **Complete candidate-neutral interface** — PASS. `SSHContracts.swift` exposes factory,
   transport, byte/exec channel protocols, dependencies, configuration, policies, errors,
   metrics/events/snapshot. Imports only Foundation + CryptoKit (fingerprint hashing).
   `check-core-boundaries.sh` now also greps Core for
   `ReluxNIOSSH|SwiftNIO|NIOSSH|libssh2|OpenSSL` and passes.
2. **Host evidence before credentials** — PASS, enforced at type level: `SSHHostKeyAcceptance`
   has a fileprivate init reachable only through `SSHHostKeyDecision.acceptance(for:)`
   (throws on every reject), and `SSHCredentialRequest` requires that acceptance value.
   Canonical `SHA256:<base64-no-padding>` fingerprint computed in `SSHHostKeyEvidence.init`.
   All 6 host decisions and all 9 auth outcomes represented; mapping helpers preserve
   category, phase, and retry disposition.
3. **Bounded channel surface** — PASS. Partial `writeSome`, `read(maximumBytes:)`,
   stderr + `waitForExit`, idempotent `finishWriting`/`close`, `reset`, `cancel`,
   exec-stdin upload validated against channel policy, and receive-window snapshot with
   overflow-checked invariant remaining+buffered+delivered <= cap; `SSHWindowAdjustment`
   enforces before+amount==after <= cap.
4. **Clock/policy/rekey/keepalive/events/metrics** — PASS. 14-site `SSHTimeoutPolicy`
   matches contract section 11 exactly; 4 client rekey reasons + serverInitiated;
   schema-v1 hardcoded; 35 counters and 11 gauges match section 13 exactly (tests assert
   enum rawValue lists and Mirror field order of the snapshot structs).
5. **Fixtures + boundary + build** — PASS. 12 focused Swift Testing fixtures cover state
   transitions, policy validation, host ordering with spies, auth mapping, channel
   semantics, window caps, upload typing, rekey/keepalive schema, stable error codes,
   metric schema, privacy sentinels, and two-factory type erasure.

## Non-blocking nits (no rework required)

- `SSHValidationField.maximumReadBytes` is declared but unused in Core; runtime read
  validation is adapter-side via `SSHTransportError(.invalidArgument)`. Harmless reserve.
- `permitsTransition` forbids `closing -> failed`, a stricter reading than the doc's
  "any nonterminal state -> failed". Defensible: teardown in progress just completes;
  adapters own actual transitions.
- Privacy fixture is sentinel-based over `String(reflecting:)`; the structural absence of
  sensitive fields in event/snapshot/error types is the real enforcement. Deep
  verification belongs to E-METRICS-PRIVACY in the conformance suite (out of scope here).

## Verdict

accepted -> done. Unblocks TASK-260715-1af33i, TASK-260715-1ozsb6, TASK-260715-2d3g5e.
