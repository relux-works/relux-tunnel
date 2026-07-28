# TASK-260715-ypo7yo — independent architecture review verdict 01

Verdict: CHANGES REQUESTED.
Review route: analysis.
Reviewed 2026-07-28 as reviewer. No portal mutation is authorized by this verdict.

## Blocking findings

### F1 — Network Extension entitlement is not modeled by signing channel

The JSON gives every macOS host/provider target one fixed value,
`packet-tunnel-provider-systemextension`, while the same JSON authorizes Mac
Development profiles for all four C1 macOS App IDs.

Apple DTS states that both the container app and embedded provider need the
Network Extension entitlement, but the value varies by distribution channel:
direct Developer ID signing uses the `-systemextension` suffix; development
signing uses the value without that suffix.

Source:
https://developer.apple.com/forums/thread/800887#159-168

Independent targeted gate over the attached authoritative JSON:
- four C1 Mac Development rows observed
  `packet-tunnel-provider-systemextension`
- expected for development signing:
  `packet-tunnel-provider`
- exit code 1

Impact: AC2 and AC3 fail. Ceremony C1 would ask the operator to create Mac
Development profiles against the wrong entitlement value. The target schema,
profile rows, C1 capability scope, verification A3, validator R7/R17, and prose
sections 4 through 6 must encode per-signing-channel entitlement values. Keep
the suffix for direct Developer ID distribution and use the plain value for
development signing, on both members of each host/provider pair.

### F2 — the App Group “same record, different literal” rule conflates two identifiers

The contract registers `group.works.relux.tunnel` but makes the macOS
entitlement claim `262RZ595FP.group.works.relux.tunnel`, calling it the same
portal record with a team prefix. Apple distinguishes these as two App Group ID
styles:

- iOS-style: begins `group.`, allocated on the Developer website, and
  authorized by a provisioning profile.
- macOS-style: begins with the Team ID and cannot be explicitly allocated on
  the Developer website.

Since February 2025, iOS-style App Group IDs are fully supported and recommended
for new macOS code; Xcode 16.3 and later default to that model.

Source:
https://developer.apple.com/forums/thread/721701#34-81

Impact: AC2 and AC3 fail. The macOS literal currently does not identify the
registered portal record the artifact says it consumes, and C1 creates records
that the macOS entitlement rows do not literally claim. For this new Xcode 26.5
project, use the registered bare `group.works.relux.tunnel` and probe group on
both platforms unless a documented project constraint requires the older,
separate macOS-style identity. If the older style is intentionally retained,
model it as a distinct unregistered identifier and remove the cross-platform
same-record claim and unused C1 portal dependency. Update R9, R10, R18 and the
profile assertions accordingly.

### F3 — verification assertion A10 is not executable as written

A10 rejects every entitlement key outside the target matrix union, but the
matrix does not model signing-generated entitlements such as the platform
application identifier, team identifier, and development get-task-allow key.
Apple documents that Xcode adds the application identifier during signing:
https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps

Impact: AC3 fails. A10 would reject a legitimate signed development bundle, or a
consumer would need undocumented exceptions. Define an exact per-platform,
per-profile allowlist that separates project-authored capabilities from
signing-generated entitlements, then test both missing required keys and
unexpected extra keys.

### F4 — App Sandbox rationale overstates the Apple requirement

Apple requires App Sandbox for the NE provider system extension, but direct
Developer ID distribution does not itself require the containing host to be
sandboxed. The repository independently requires a sandboxed host for its
Sparkle design in `.spec/platform-distribution.md`.

Impact: entitlement effect may remain unchanged, but AC2 requires accurate
target differences and rationale. Attribute provider sandboxing to the NE
provider requirement and host sandboxing to the accepted project architecture,
not to a single Apple rule covering both.

## Gates and evidence

- Attached self-validator: 247 checks, PASS, exit code 0. It does not cover the
  signing-channel defect above.
- Reviewer signing-channel gate: FAIL, exit code 1.
- `task-board validate`: PASS, exit code 0.
- `scripts/check-legacy-preservation.sh`: PASS, exit code 0. The shipped
  `works.relux.proxy` identity remains intact.
- Repository/spec review: the four production identifiers, reciprocal
  containment, no-migration rule, probe justification, research-gap record, and
  linked dependency structure are acceptable.

Overall test gate: failing because the reviewer entitlement-channel assertion
fails. No implementation source was changed by this review.

## Required rework before the next review

1. Revise JSON and Markdown to model Network Extension values per signing/profile
   channel, including exact C1 development and later Developer ID rows.
2. Make the App Group identifier model consistent with current Apple semantics;
   prefer the registered bare `group.` identifiers on macOS and iOS for this
   new project.
3. Replace A10 with explicit per-target/channel authored and generated
   entitlement allowlists.
4. Correct the App Sandbox rationale.
5. Extend the validator and negative mutation gates so each defect above fails
   closed; update the handoff evidence and preserve the accepted identity,
   legacy, probe, and dependency decisions.

This is ordinary evidence-backed metadata rework. No external blocker or human
decision is required.