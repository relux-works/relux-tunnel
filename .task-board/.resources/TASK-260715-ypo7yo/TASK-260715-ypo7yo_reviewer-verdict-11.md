# TASK-260715-ypo7yo reviewer verdict 11

Verdict: **ACCEPTED**.

Independent architecture review accepts matrix revision **2026-07-28.r12**.
No Apple Developer portal mutation has begun; the accepted C1 authorization
remains limited to the four macOS App IDs, the Network Extensions capability on
all four, and one Mac Development profile per App ID.

## Acceptance evidence

- The production identifiers are exact and disjoint:
  `works.relux.tunnel.ios`, `works.relux.tunnel.ios.tunnel`,
  `works.relux.tunnel.mac`, and `works.relux.tunnel.mac.tunnel`. Each provider
  is the containing host identifier plus `.tunnel`; the macOS provider embeds
  as a system extension and the iOS provider as an app extension.
- The disposable probe identifiers are separately justified by the two
  story-owned probe tasks, use the disjoint `works.relux.tunnel.probe.*`
  namespace, are development-only, and do not repurpose a production or legacy
  identity.
- Network Extension values are derived per signing channel:
  `packet-tunnel-provider` for Mac/iOS development and iOS App Store profiles,
  and `packet-tunnel-provider-systemextension` only for Developer ID profiles.
  Both hosts and providers carry the entitlement as Apple requires.
- App Groups and Keychain sharing are least-privilege and target-specific:
  production iOS host/provider receive the one shared App Group and Keychain
  access group; iOS probes and every macOS target are prohibited. The macOS
  provider uses the ACL-controlled system-domain keychain selected by
  `TASK-260728-7ii1xz`. The macOS 15 sandbox-policy uncertainty is represented
  as unarmed conditional exception `X1-C1`, owned and gated rather than silently
  granted.
- Team prefix, App Identifier Prefix verification, debug/release identity
  stability, development/distribution profile classes, device binding, and
  cross-platform sharing are explicit and machine-checkable.
- `works.relux.proxy` is forbidden to this namespace and remains unchanged.
  `scripts/check-legacy-preservation.sh` independently verified the shipped
  `v0.1.0` identity and bytes.
- Ceremony C1 (`TASK-260728-q5kjta`) names revision r12 and authorizes exactly
  the four macOS App IDs, Network Extensions only, and four Mac Development
  profiles. It explicitly excludes all iOS App IDs, App Group creation,
  App Groups capability changes, Keychain portal mutation, distribution
  profiles, and `works.relux.proxy`.
- The story decomposition is the minimal three-task split needed by the spec:
  one decision matrix and one disposable viability probe per platform. Each
  task is atomic and dependency-linked. Rule D1 verifies all 20 declared matrix
  consumers transitively depend on this task, with the one upstream
  architecture-decision exemption verified in the opposite direction.
- No planning diagram was produced or required. The matrix, rationale,
  validators, preservation baselines, logs, and handoff are task-scoped outcome
  resources. Relevant decisions, anomalies, and the known unrelated test race
  are recorded in `LOGBOOK.md`.

## Independent gates

| Gate | Result | Exit |
| --- | --- | --- |
| `TASK-260715-ypo7yo_validate-matrix.py` | 2862 checks | 0 |
| `TASK-260715-ypo7yo_mutate.py` | 285/285 negative gates | 0 |
| `TASK-260715-ypo7yo_check-portal-consumer.py --repo .` | A1 28, P1 20, D1 41 | 0 |
| `TASK-260715-ypo7yo_preserve.py` | 122 assertions | 0 |
| `TASK-260715-ypo7yo_preserve-r10.py` | 201 assertions | 0 |
| `TASK-260715-ypo7yo_preserve-r11.py` | 143 assertions | 0 |
| `TASK-260715-ypo7yo_preserve-r12.py` | 245 assertions | 0 |
| `TASK-260715-ypo7yo_reviewer-gates.sh` | all gates and 8 controls hold | 0 |
| `scripts/check-legacy-preservation.sh` | legacy contract preserved | 0 |
| `task-board validate` | no issues | 0 |
| `swift test` | 335 tests in 29 suites | 0 |
| scoped `git status` / `git diff --stat` | no product, test, script, protocol, relay, package, or spec changes | 0 |
| `git diff --check` on current task/logbook records | clean | 0 |

The previously recorded UDP adapter snapshot race remains tracked separately as
`BUG-260728-2j25tu`; it did not reproduce in this review run and is outside this
metadata decision task.

This reviewer run supplies no `commit_ack`.
