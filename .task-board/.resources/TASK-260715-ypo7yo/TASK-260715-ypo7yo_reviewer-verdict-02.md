# TASK-260715-ypo7yo — independent architecture review verdict 02

Verdict: CHANGES REQUESTED.
Review route: analysis.
Reviewed 2026-07-28 as reviewer. No portal mutation is authorized by this verdict.

## Blocking finding

### F1 — exhaustive macOS host allowlist omits the required Sparkle Mach lookup entitlement

The accepted project architecture requires the sandboxed ReluxProxyMac host to enable SUEnableInstallerLauncherService and Sparkle documented <host-bundle-id>-spks and <host-bundle-id>-spki Mach lookup exceptions at .spec/platform-distribution.md:99-106. The authoritative JSON acknowledges those exceptions in the macos.host App Sandbox requirementBasis, but it does not define com.apple.security.temporary-exception.mach-lookup.global-name in macos.host.entitlements. The Markdown matrix likewise mentions the exceptions at line 252 while A10b at line 507 and the computed allowlist at lines 524-527 declare that every present signed entitlement must come from the matrix-authored rows or the signing-generated set.

Official Sparkle sandboxing guidance requires exactly com.apple.security.temporary-exception.mach-lookup.global-name with values $(PRODUCT_BUNDLE_IDENTIFIER)-spks and $(PRODUCT_BUNDLE_IDENTIFIER)-spki: https://sparkle-project.org/documentation/sandboxing/ . Apple documents that this entitlement enables lookup of named global Mach services: https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html .

Independent targeted gate over TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.json:

```sh
jq -e \u0027(.targets[] | select(.key == "macos.host")) as $h | ($h.entitlements["com.apple.security.temporary-exception.mach-lookup.global-name"] // null) as $e | ($e.status == "required-adjacent" and $e.value == ["$(PRODUCT_BUNDLE_IDENTIFIER)-spks", "$(PRODUCT_BUNDLE_IDENTIFIER)-spki"] and $e.requirementSource == "project-architecture")\u0027 TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.json
```

Output: false. Exit code: 1.

Impact: AC3 fails because the purported machine-checkable allowlist rejects the entitlement required by the accepted project architecture. The solution-fit and completeness checklist gates also fail. A generated, correctly configured sandboxed Sparkle host would either fail A10b or require an undocumented exception, recreating the same defect class as reviewer verdict 01 F3.

## Required rework

1. Add com.apple.security.temporary-exception.mach-lookup.global-name to macos.host only, with status required-adjacent, exact two-value array $(PRODUCT_BUNDLE_IDENTIFIER)-spks and $(PRODUCT_BUNDLE_IDENTIFIER)-spki, portalCapability false, owner, project-architecture attribution, and the spec plus Sparkle basis. Do not grant it to providers, iOS targets, or probe targets.
2. Add a validator rule that pins the key, target, exact values, attribution, and absence elsewhere. Add structural negative gates for missing key, wrong value, and grant to an unrelated target.
3. Update the Markdown entitlement table, allowlist evidence, handoff evidence, positive and negative gate log, and relevant logbook entry.
4. Preserve all accepted r2 decisions: four production identifiers and containment, channel-keyed Network Extension values, identical registered iOS-style App Group literals, Keychain withholding on macos.provider, legacy no-migration rule, C1 scope, gap task, and dependencies.

## Passing gates retained as evidence

- validate_matrix.py: 537 checks PASS, exit 0, but missing coverage for F1.
- mutate.py: 23/23 negative gates hold, exit 0, but no Sparkle entitlement mutation exists.
- scripts/check-legacy-preservation.sh: PASS, exit 0.
- task-board validate: PASS, exit 0.
- swift test: 335 tests in 29 suites PASS, exit 0.

This is autonomous metadata and architecture-contract rework, not a Stop-The-Line condition. No external or human-only decision is required.