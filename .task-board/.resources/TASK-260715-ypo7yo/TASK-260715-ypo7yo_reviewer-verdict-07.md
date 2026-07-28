# TASK-260715-ypo7yo reviewer verdict 07

Verdict: CHANGES REQUESTED. Route: analysis. This is recoverable contract rework; there is no external blocker and no portal mutation is authorized yet.

## Blocking findings

1. A5 contradicts the target rows and A18. A5 says application-groups is present on every iOS bundle, but ios.probe.host and ios.probe.provider are prohibited under G4 and A18 requires the key absent. Independent target-derived gate: false, exit 1. Because the matrix is the input to automated entitlement checks, following A5 would over-entitle both disposable probes; following A18 would violate A5. The 1024-check validator misses this because R27 checks assertion membership and substrings, not semantic scope against target status.

2. A9 is not platform-scoped. It says every development profile contains this Mac, while the four iOS development profile rows declare devices as deferred under ADR-024. Independent row-derived gate: false, exit 1. A9 must distinguish the four C1 macOS Mac Development profiles from deferred iOS development profiles and later compare each profile with its platform-appropriate declared device set.

## Required rework

Make A5 name only ios.host and ios.provider and preserve A18 for the probe pair. Make A9 conditional by platform/channel and aligned with profiles[].development.devices. Update the Markdown projection. Add validator rules and negative mutations that derive both assertion scopes from authoritative rows, so a future row move or stale assertion fails closed. Bump and re-point the revision consumers per A1/P1.

## Independent gates

validate_matrix.py: 1024 checks, exit 0. check-portal-consumer.py --repo project-root: 43 checks, exit 0. preserve.py r6-to-r7: 57 assertions, exit 0. mutate.py: 130/130, exit 0. check-legacy-preservation.sh: exit 0. task-board validate: exit 0. swift test: 335 tests in 29 suites, exit 0. A5 target-consistency gate: false, exit 1. A9 profile-device-scope gate: false, exit 1.

All other reviewed surfaces remain acceptable: exact production and probe identifiers and containment, least-privilege target rows, channel-specific Network Extension values, App Group and Keychain records, legacy works.relux.proxy preservation, live C1 and portal-consumer alignment, dependencies, and attached task-scoped artifacts.