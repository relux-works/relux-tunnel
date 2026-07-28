# TASK-260715-ypo7yo — independent architecture review verdict 03

Verdict: **CHANGES REQUESTED**.
Review route: **analysis**.
Reviewed 2026-07-28 as reviewer. No portal mutation is authorized by this
verdict.

## Blocking finding

### F1 — macOS App Groups are pre-granted before they have a required function

The matrix correctly establishes that a user-context macOS containing app and a
root-context Network Extension system extension do not share the same App Group
container. It then assigns
`com.apple.security.application-groups = ["group.works.relux.tunnel"]` to both
macOS production targets as `required`, even though:

- `appGroupPurposeRule.macOS` says the group is retained for the channel that
  `TASK-260728-7ii1xz` **will** select;
- the gap task explicitly compares transports including
  `NETunnelProviderSession` app-provider messaging and XPC, so an App Group
  namespace is not established as a requirement of every viable transport;
- OC-4 says the App Group style question has matrix effect **"none today"**; and
- the stated rationale includes avoiding a repeated Ceremony C1, which is an
  operational convenience rather than a least-privilege requirement.

Apple's Network Extension guidance distinguishes app-provider messages, which
are supported directly by Network Extension, from App Group based state/IPC.
Apple also confirms that a system extension runs as root and therefore receives
a different App Group container from its user-context containing app. App
Groups can authorize Mach IPC and other communication, but only once the
selected design actually uses such a channel:

- https://developer.apple.com/forums/tags/networkextension
- https://developer.apple.com/documentation/xcode/configuring-app-groups

Independent targeted gate over the authoritative JSON:

```sh
jq -e '
  ((.appGroupPurposeRule.macOS
      | contains("selected by TASK-260728-7ii1xz will use"))
    and
    ((.openConstraints[] | select(.id == "OC-4") | .matrixEffect)
      | startswith("none today"))) as $future_only
  |
  ([.targets[]
    | select(.key == "macos.host" or .key == "macos.provider")
    | .entitlements["com.apple.security.application-groups"].status]
    | all(. != "required"))
  or ($future_only | not)
' TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.json
```

Output: `false`. Exit code: **1**.

Impact: AC2 and the least-privilege Definition of Done fail. The current
contract authorizes a portal capability and signed entitlement based on a
possible future transport rather than a concrete target requirement.

## Required rework

1. Resolve the macOS App Group grant before Ceremony C1:
   - either cite the selected, current macOS host/provider transport and prove
     why that transport requires this exact App Group entitlement on each macOS
     target; or
   - mark the macOS rows withheld pending `TASK-260728-7ii1xz`, then update C1
     scope and dependency ordering so portal mutation cannot pre-grant them.
2. Do not use avoiding another human ceremony as the capability rationale.
   Ceremony/dependency planning must follow the least-privilege decision.
3. Add a validator rule and adversarial mutation that fail when a macOS App
   Group is `required` while its only named function remains conditional on an
   unresolved transport decision.
4. Update the JSON, Markdown, handoff evidence, and logbook consistently while
   preserving the accepted identifier, containment, Network Extension,
   Keychain-withholding, legacy, Sparkle-exception, profile, and C1-exclusion
   decisions.

## Secondary correction

Markdown section 9.1 says the `macos.host` development allowlist resolves to
"exactly seven keys", but the list contains seven authored keys plus two
always-generated keys plus one development-only key: **10 total**. The JSON is
internally correct; fix the prose count during rework.

## Gates and accepted evidence

- `validate_matrix.py`: 598 checks PASS, exit **0**.
- `mutate.py`: 41/41 negative gates hold, exit **0**; none covers F1 above.
- `scripts/check-legacy-preservation.sh`: PASS, exit **0**.
- `task-board validate`: PASS, exit **0**.
- `swift test`: 335 tests in 29 suites PASS, exit **0**.
- Reviewer least-privilege App Group gate: FAIL, exit **1**.

The four production identifiers, reciprocal containment, channel-specific
Network Extension values, iOS-style App Group literals, macOS provider Keychain
withholding, team-prefix handling, environment identity rules, profile classes,
legacy no-migration rule, probe justification, board size, traceability, and
dependency records are otherwise acceptable. No architecture diagram is
required for this correction.

This is autonomous architecture-contract rework, not a Stop-The-Line condition.
No external blocker or human-only decision is required.
