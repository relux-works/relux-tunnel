# TASK-260715-3cv3r4 independent review 03 outcome

## Verdict

Accepted. The review-02 lifecycle-accounting finding is closed, the previously accepted profile, Keychain, host-policy, ordering, redaction, and safety behavior remains intact, and no material finding remains.

## Independent lifecycle evidence

- One `FixtureLifecycleRegistry` actor is owned by the test and shared by every transport across all 16 bounded repetitions. Tokens are monotonically allocated into the registry dictionary, so a prior-iteration leak remains in every later snapshot.
- `FixtureTransport` registers task, connection, and observer tokens at lifetime start. Host-policy, credential-provider, and signing callbacks each use a balanced callback-token scope. Success retains connection and observer ownership until explicit close; every rejection, injected throw, and gated cancellation releases task, connection, observer, and callback tokens through concrete token removal. No counter assignment, registry reset, `removeAll`, or catch-time compensation exists.
- The checked-in gated cancellation test observes the exact non-zero live state `tasks=1, connections=1, observers=1, callbacks=1` before release and returns to the single shared baseline after cancellation.
- A temporary review-only probe retained one observer token across a later successful connect/close lifecycle and observed it still present; exit 0. A second probe released one callback token twice and produced the expected Swift Testing issue `fixture lifecycle token released more than once`; exit 1. Both probes were removed, and the task diff SHA-1 before and after was identical: `567a73567235b5d747fd4da2ea84bcd05b2273f6`.

## Reconfirmed behavior

- All nine `SSHHostKeyDecision` cases traverse the candidate-neutral transport seam. The two accepted cases order `hostPolicy -> credentialLookup -> authentication`; all seven rejected cases stop at `hostPolicy` with zero credential, signing/authentication, and channel/open work.
- Fixture Keychain handles are internal and inert. `LiveMacOSSystemKeychainSecurityClient` rejects them before its internal injected matcher, and the spy records zero matcher calls. Live queries retain one exact search-list item, `kSecMatchLimitOne`, and no fallback or enumeration.
- Invalid snapshot classes enter the real `TunnelRuntimeCoordinator` startup composition boundary and stop before injected Keychain/network probes. The exhaustive loader suite covers the individual schema, generation, host, trust, credential, prohibited-field, encoding, and atomic-generation rules.
- Redaction tests and scans cover synthetic secrets, hostnames, full addresses, fingerprints, raw key material, snapshots, errors, and captured logs. No real Keychain, SSH/network, provider, VPN, route, DNS, interface, or packet-filter action ran.

## Independent validation matrix

| Command | Exit | Result |
| --- | ---: | --- |
| `swift test --enable-code-coverage --filter focused-six-suite-expression` | 0 | 53 tests in 6 suites passed. |
| Three repetitions each of Keychain resolver, SSH contract seam, and bootstrap error suites | 0 | 9/9 invocations passed. |
| `xcrun llvm-cov report` for five affected production files | 0 | 87.75% lines; 87.04% functions. |
| Temporary prior-retention review probe | 0 | Retained observer stayed visible across a later full lifecycle, then explicit release restored zero. |
| Temporary double-release review probe | 1 expected | Swift Testing recorded the deliberate duplicate-release issue. |
| Final focused suite after removing probes | 0 | 53 tests in 6 suites passed; task diff restored byte-for-byte. |
| `swift format lint --recursive Sources Tests Package.swift` | 0 | Clean. |
| `./scripts/check-core-boundaries.sh` | 0 | Valid. |
| `git diff --check` | 0 | Clean. |
| Prohibited-data, live-Security test, live-network test, public-seam, and self-reset scans | 0 | Wrapper-confirmed no prohibited matches. |
| Production Security API inventory | 0 | Only default/injected `SecItemCopyMatching` and private system-domain resolution remain. |
| `task-board validate` | 0 | Reports the known dependency-gated parent aggregate anomaly: story `STORY-260715-2wjwuf` remains `to-dev` while this task is `reviewing`. This is separate from task correctness. |

## Evidence logs

- `.temp/TASK-260715-3cv3r4-review-03/focused-coverage-01.log`
- `.temp/TASK-260715-3cv3r4-review-03/repeated-cleanup-01.log`
- `.temp/TASK-260715-3cv3r4-review-03/coverage-report-01.log`
- `.temp/TASK-260715-3cv3r4-review-03/review-probe-prior-retention.log`
- `.temp/TASK-260715-3cv3r4-review-03/review-probe-double-release.log`
- `.temp/TASK-260715-3cv3r4-review-03/focused-final-after-probes.log`
- `.temp/TASK-260715-3cv3r4-review-03/format-lint-final.log`
- `.temp/TASK-260715-3cv3r4-review-03/core-boundaries-final.log`
- `.temp/TASK-260715-3cv3r4-review-03/diff-check-final.log`
- `.temp/TASK-260715-3cv3r4-review-03/prohibited-data-scan-01.log`
- `.temp/TASK-260715-3cv3r4-review-03/live-security-test-scan-01.log`
- `.temp/TASK-260715-3cv3r4-review-03/live-network-test-scan-01.log`
- `.temp/TASK-260715-3cv3r4-review-03/public-seam-scan-01.log`
- `.temp/TASK-260715-3cv3r4-review-03/self-reset-scan-01.log`
- `.temp/TASK-260715-3cv3r4-review-03/production-security-inventory.log`
- `.temp/TASK-260715-3cv3r4-review-03/task-board-validate-01.log`

## Residual scope

Repository-wide and opt-in loopback/real-host SSH integration were intentionally not run because the binding brief prohibits network activity. The focused SwiftPM matrix builds the shared test bundle and covers the affected production scope above the required target.
