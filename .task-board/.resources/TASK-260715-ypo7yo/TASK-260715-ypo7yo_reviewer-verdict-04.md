# TASK-260715-ypo7yo — independent architecture review verdict 04

Verdict: **CHANGES REQUESTED**.
Review route: **analysis**.
Reviewed 2026-07-28 as reviewer. No portal mutation is authorized by this verdict.

Revision `2026-07-28.r4` correctly closes verdict 03: the prior macOS App Group gate now returns `true` with exit **0**, and all four production identifiers plus reciprocal containment independently match with exit **0**. The remaining failures are different acceptance-contract gaps.

## Blocking findings

### F1 — the macOS host custom Keychain access group has no sharing consumer

The matrix authors `keychain-access-groups = ["$(AppIdentifierPrefix)works.relux.tunnel.shared"]` on `macos.host` as `required`. Its own rationale says the macOS provider never reads this group; the only macOS uses named are the host vault and a host-owned pre-seed staging item. Persistence across an interrupted approval flow does not require a shared access group.

Apple defines access groups as a way for multiple apps or targets to share Keychain items, and states that an app is always in a private default group that lets it store and retrieve its own items. The custom shared group therefore expands the signed entitlement without enabling any current macOS consumer:

- https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps
- https://developer.apple.com/documentation/xcode/configuring-keychain-sharing
- https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains

Independent gate:

```sh
jq -e '
  [.targets[]
   | select(.platform == "macOS")
   | select(.entitlements["keychain-access-groups"].status == "required")]
  | length == 0
' TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.json
```

Output: `false`. Exit code: **1**.

Impact: AC2 and the least-privilege Definition of Done fail. The provider-side correction in K1 is sound, but the same least-privilege test was not applied to the host row.

Required rework: either prohibit the custom Keychain group on `macos.host` and update K1, A6, allowlists, consumers, Markdown, validator, mutations, downstream consequences, and logbook; or identify a second current macOS target that reads the same Data Protection Keychain group and link the exact requirement. A host-only staging item is not such a consumer.

### F2 — Ceremony C1 still instructs the operator to authorize a different set than r4

The authoritative JSON now authorizes four macOS App IDs, zero App Group records, and no App Groups capability. It explicitly excludes four iOS App IDs. However, `TASK-260728-q5kjta`, which is directly blocked by this task and becomes runnable after acceptance, still says its sitting authorizes:

- a singular host App ID and packet-tunnel extension App ID rather than the production and probe pairs;
- an App Group and a Keychain access group; and
- exclusion of only two iOS identifiers.

That conflicts with `c1AuthorizationScope`, where `authorizedAppIds` has four entries, `authorizedAppGroups` is empty, and four iOS identifiers are explicitly not authorized. It also conflicts with the matrix statement that Keychain sharing has no separate portal record.

Impact: AC5 fails. Accepting this task would unblock the sole human authorization node with instructions that can under-authorize the probe pair and over-authorize an App Group. A downstream-consequence paragraph in the matrix does not replace the board task contract the operator receives.

Required rework: update `TASK-260728-q5kjta` scope and AC to name the same four macOS App IDs, Network Extensions capability only, zero App Group records/capabilities, no separate Keychain-group portal mutation, four excluded iOS App IDs, and the exact development profile class. Keep the existing dependency on this task. This is autonomous metadata rework, not a human decision.

### F3 — the iOS probe App Group grant is not traced to the probe contract

Both iOS probe rows mark `com.apple.security.application-groups` as `required` and claim the disposable probe exercises the production shared-container path. `TASK-260715-1jckn0` instead scopes the probe to `NETunnelProviderManager` save/load/start/status, versioned app messaging, and clean stop; it names no App Group snapshot or UserDefaults exchange. Its description says the probe exercises only those paths.

Independent traceability gate under the current probe contract:

```sh
jq -e '
  [.targets[]
   | select(.key == "ios.probe.host" or .key == "ios.probe.provider")
   | .entitlements["com.apple.security.application-groups"].status]
  | all(. == "prohibited")
' TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.json
```

Output: `false`. Exit code: **1**.

Impact: AC2 and the requirement-to-element traceability checklist fail for the beyond-literal probe rows.

Required rework: either withhold the App Group from the iOS probe pair, or amend the probe task with a concrete shared-container deliverable, AC, and archive/runtime evidence plus a written gap justification showing why that extra probe function is required. “Approved entitlements” cannot justify itself circularly.

## Gates

- `validate_matrix.py`: 801 checks PASS, exit **0**.
- `mutate.py`: 66/66 negative gates hold, exit **0**.
- `scripts/check-legacy-preservation.sh`: PASS, exit **0**.
- `task-board validate`: PASS, exit **0**.
- `swift test`: 335 tests in 29 suites PASS, exit **0**.
- verdict-03 macOS App Group gate: PASS, exit **0**.
- production identifier and containment gate: PASS, exit **0**.
- macOS host custom Keychain-group least-privilege gate: FAIL, exit **1**.
- iOS probe App Group traceability gate: FAIL, exit **1**.

The exact production identifiers, containment, channel-specific Network Extension values, legacy no-migration rule, macOS App Group prohibition, macOS provider Keychain prohibition, Sparkle exception, team-prefix rules, environment rules, and profile classes are otherwise acceptable.

These are recoverable architecture/metadata corrections. They are not Stop-The-Line conditions and require no external or human-only decision.