# TASK-260715-ypo7yo reviewer verdict 08

Verdict: **CHANGES REQUESTED**. Route: `analysis`.

This is recoverable architecture/evidence rework. It is not a Stop-The-Line
external blocker, and no portal mutation is authorized.

## Blocking finding

### F1 — the “no System-keychain file exception” decision is proved only on macOS 26.5, not on the supported macOS 15.0 floor

The binding specification sets the generated macOS deployment target to 15.0
and requires the oldest supported signing/runtime requirements to remain
testable (`.spec/platform-distribution.md:41-62`).

The matrix nevertheless settles `macos.provider` without any
`com.apple.security.temporary-exception.files.absolute-path.read-write` row and
states that the provider needs no keychain-related entitlement or exception
because `/System/Library/Sandbox/Profiles/application.sb:792-793` grants
`/Library/Keychains` read/write to every Network Extension process. Every cited
observation is explicitly from macOS 26.5 (25F71)
(`TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.md:395-410`,
JSON `targets[key=macos.provider].entitlements[keychain-access-groups]`).

That evidence proves the current physical baseline only. It does not prove that
the base App Sandbox grant and the unconditional `securityd` Mach lookups exist
on macOS 15.0. The contract currently has no OS-version constraint for this
assumption, no temporary-file-exception row, and no reopening condition for
sandbox-policy drift; K1 reopens only if the provider moves into a user context.
Because the matrix is the source for generated entitlements and automated
allowlist checks, a required floor-specific exception would be rejected as
drift and the provider could fail to reach its selected System-keychain
transport on a supported OS.

The installed-product observation does not close this gap: the artifact itself
records that Surfshark ships a `/Library/Keychains/` temporary exception and
correctly says that this is not proof of necessity. It is likewise not proof of
redundancy on macOS 15.

## Required rework

1. Verify the `/Library/Keychains` read/write grant and required
   `securityd`/`SecurityServer` Mach lookups on macOS 15.0 (and the actual
   oldest supported runtime policy) using primary or system evidence, with a
   task-scoped transcript and real exit codes; or model the unresolved
   version-specific exception requirement explicitly.
2. Extend K1/X1 and the `macos.provider` reopening/amendment conditions so an
   OS-floor sandbox-policy difference cannot be silently rejected by the
   generated entitlement allowlist.
3. Add a machine-checkable assertion and negative mutation for this
   version-scope rule, and name the existing downstream owner that verifies it.
   Do not create another board element unless no existing platform-floor or
   signed-provider task owns the check.
4. Keep Ceremony C1 least-privilege scope unchanged unless evidence identifies
   a portal-managed capability; a temporary file exception is not itself a new
   App ID record.
5. If the r8→r9 preservation result remains part of the handoff, attach or
   otherwise durably materialize its r8 input. `preserve.py` is attached, but
   the claimed input was only `/tmp/r8-baseline.json`, so that one historical
   gate is not independently rerunnable from task-scoped outcomes.

## Accepted surfaces

No other blocking issue was found. The review independently confirmed:

- exact production identifiers and host/provider containment;
- development versus Developer ID Network Extension values;
- iOS-only App Group and Keychain sharing, with justified probe exclusions;
- Team/App ID prefix blocker handling and stable environment naming;
- legacy `works.relux.proxy` non-collision and explicit migration ownership;
- exact four-entry macOS C1 authorization, iOS deferral, and profile classes;
- probe-identity justification against the goal and probe tasks;
- live consumer dependency reachability and the r9 D1/N1 contract checks;
- proportional board decomposition and concrete spec/gap traceability.

Apple’s current documentation independently corroborates the channel-specific
Network Extension values and the distinction between file-based Keychain ACLs
and Data Protection Keychain access groups:

- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension
- https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains
- https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps

## Independent gates

| Gate | Result |
| --- | --- |
| `validate-matrix.py` | 2483 checks, exit 0 |
| `mutate.py` | 202/202 negative gates, exit 0 |
| `check-portal-consumer.py --repo <project>` | 84 checks / 3 rules, exit 0 |
| `reviewer-gates.sh` | current A5/A9/D1 checks, exit 0 |
| `scripts/check-legacy-preservation.sh` | exit 0 |
| `task-board validate` | exit 0 |
| `swift test` | 335 tests in 29 suites, exit 0 |

`preserve.py` was not rerun because its required r8 JSON input is not attached
as a task-scoped outcome. No gate was reported green without being executed.
