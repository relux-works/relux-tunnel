# TASK-260715-ypo7yo — independent architecture review verdict 05

Verdict: **CHANGES REQUESTED**.
Review route: **analysis**.
Reviewed 2026-07-28 as reviewer. No portal mutation is authorized by this
verdict.

Revision `2026-07-28.r5` correctly closes verdict 04's target-row findings:
`keychain-access-groups` is prohibited on every macOS target, the iOS probe pair
has no App Group, Ceremony C1 now names the exact four macOS App IDs, and the
four production identifiers plus reciprocal containment independently match.
Two acceptance-contract inconsistencies remain outside the row-level checks.

## Blocking findings

### F1 — the authoritative JSON contradicts itself about the macOS Keychain grant

The target rows, `keychainAccessGroups[0].platforms`,
`keychainAccessGroups[0].consumedByTargets`, rule K2, assertions A6/A17, and the
r5 revision log all say `keychain-access-groups` is granted only to
`ios.host` and `ios.provider` and is absent from every macOS target.

However, `crossPlatformRules[2]` still says:

> One Keychain access group NAME, granted only where it is functional (rule K1):
> the iOS host and appex, and the macOS host.

That is the superseded r4 contract. `crossPlatformRules` is inside the
authoritative machine-readable JSON, and AC3 specifically requires
cross-platform sharing rules to be explicit and machine-checkable. A consumer
that reads the cross-platform summary can re-grant the exact entitlement K2 and
A17 prohibit.

Independent gate:

```sh
jq -e '
  (.crossPlatformRules
    | map(select(test("Keychain access group")))[0]
    | (contains("macOS host") | not))
  and
  ([.targets[]
    | select(.entitlements["keychain-access-groups"].status == "required")
    | .key] == ["ios.host", "ios.provider"])
' TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.json
```

Output: `false`. Exit code: **1**.

The supplied validator reports 846 passing checks with exit 0, so it does not
cover this cross-projection consistency.

Required rework:

1. Update `crossPlatformRules[2]` to the r5/K2 contract: the shared group is
   granted to the iOS host and provider only; every macOS target uses no custom
   Keychain access group.
2. Make the validator derive or compare the cross-platform statement against
   the actual target statuses and `keychainAccessGroups[].consumedByTargets`.
3. Add a parsed-object negative mutation that restores the stale macOS-host
   claim and must fail with the new rule.
4. Review the adjacent App Group summary wording ("one record per family" /
   "records themselves stay defined") against the r5 fact that the probe record
   was deleted, so the same stale-summary class is closed rather than patched
   at one string.

### F2 — the portal mutation task still carries the pre-r5 capability contract

The matrix names `TASK-260715-3jloqy` as `authorizesPortalMutationBy` and as its
portal-provisioning consumer. That task is directly blocked by this matrix and
becomes eligible after the matrix and Ceremony C1 are accepted. Its current
board contract still says:

- description: create App IDs and **shared groups**;
- scope: provision packet-tunnel, **App Group, and Keychain capabilities**;
- AC1: the macOS App IDs and **shared groups exist**; and
- AC2: the packet-tunnel entitlement appears **only on provider identifiers**.

All four statements conflict with r5. Ceremony C1 and
`c1AuthorizationScope` authorize four macOS App IDs, Network Extensions on all
four host/provider identifiers, zero App Group records or capabilities, no
Keychain access-group portal mutation, and one Mac Development profile per App
ID. Apple requires the Network Extension entitlement on both the containing app
and embedded provider; provider-only authorization is the material failure this
matrix is meant to prevent.

Independent board-contract gate over `description`, `scope`, and `ac`:

```sh
task-board q 'get(TASK-260715-3jloqy) { id description scope ac }'
# followed by a rejection of:
#   shared groups
#   packet-tunnel, App Group, and Keychain capabilities
#   packet-tunnel entitlement appears only on provider identifiers
```

Board query exit code: **0**. Consistency gate output: `false`. Gate exit code:
**1**.

Impact: AC5 and the dependency/traceability Definition of Done fail. Accepting
the matrix would leave the actual portal mutation task able to over-provision
App Groups/Keychain Sharing and under-provision both host App IDs. Correcting
only the human authorization node does not correct the unattended mutation
contract that consumes that authorization.

Required rework: update `TASK-260715-3jloqy` description, scope, AC, and
checklist to the same exact set as `c1AuthorizationScope`:

- four named macOS App IDs (production and probe host/provider pairs);
- Network Extensions enabled on all four;
- no App Group record and no App Groups capability;
- no Keychain access-group portal mutation;
- one Mac Development profile per App ID with this Mac registered;
- all four iOS App IDs and every distribution profile explicitly excluded; and
- archive/profile inspection enforcing the channel-specific unsuffixed
  `packet-tunnel-provider` value on both host and provider profiles.

This is autonomous metadata rework, not a human decision and not a
Stop-The-Line condition.

## Gates

- matrix validator: 846 checks PASS, exit **0**;
- negative mutation harness: 92/92 gates hold, exit **0**;
- `swift test`: 335 tests in 29 suites PASS, exit **0**;
- `scripts/check-legacy-preservation.sh`: PASS, exit **0**;
- `task-board validate`: PASS, exit **0**;
- production identifier uniqueness and reciprocal containment: PASS, exit **0**;
- cross-platform Keychain projection consistency: FAIL, exit **1**;
- portal task versus r5 capability contract: FAIL, exit **1**.

The first draft of the independent identifier jq helper was malformed and exited
**5** (`Cannot iterate over null`); the corrected query is the production
identifier/containment gate reported above and exited **0**. No failing product
gate was relabelled.

The exact production identifiers, containment, channel-specific Network
Extension values, target entitlement rows, Team/App-ID prefix handling,
debug-versus-release rules, profile classes, legacy no-repurposing rule, gap
record, dependency on `TASK-260728-7ii1xz`, and test evidence are otherwise
acceptable. No diagram was needed: the defects are two direct contract
contradictions, not an unclear relationship model.
