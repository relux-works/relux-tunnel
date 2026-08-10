# TASK-260715-apc34w — Apple Developer account readiness audit

Audit finalized: 2026-08-10 (Asia/Tbilisi). Verdict: **NOT READY for Gate P0 prerequisite closure; audit deliverable is ready for review.** This is a readiness finding, not a failure of the Network Extensions capability and not a request to mutate the portal.

## Privacy boundary

This report contains only the legal organization name, the non-secret Team ID, functional role names, board task IDs, capability metadata, and a truncated SHA-256 device reference. It contains no Apple Account address, credential, session/cookie, token, recovery code, certificate fingerprint/private key, Keychain secret/path, full device identifier, or account screenshot.

## Evidence basis and limits

- Accepted Ceremony C1 outcome `TASK-260728-q5kjta_results.md`: an authenticated Certificates, Identifiers & Profiles session had the Relux Works, LLC team selected; the owner confirmed authority for matrix revision `2026-07-28.r12`; prompt-free signing probes succeeded for the Relux Works Apple Development and Developer ID Application identities. C1 intentionally made no portal mutation.
- Accepted identifier contract `TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.json`: organization `Relux Works, LLC`; Team ID `262RZ595FP`; exactly four authorized macOS App IDs; Network Extensions on all four; one Mac Development profile per App ID using the current Apple-silicon Mac; iOS and all distribution profiles excluded from C1.
- Team-scoped Xcode capability cache refreshed `2026-08-10T17:18:18+04:00`: Network Extensions is `editable=true`, `isPublic=true`, `canRequestFromPortal=false`, and `distributionApprovalRequired=false`; it supports Development and Developer ID distribution and includes `packet-tunnel-provider`.
- Local codesigning inventory on 2026-08-10 contains Relux Works Apple Development and Developer ID Application identities. Certificate fingerprints and the individual operator name are omitted.
- Local device discovery on 2026-08-10 found one available Mac: `device_ref=sha256:8ea3983a9990`, model `Mac15,9`, macOS `26.5 (25F71)`, architecture `arm64e`. The digest is truncated and the source identifier is not retained.
- No Relux Works Mac Development provisioning profile was present in the inspected Xcode provisioning cache. This does not prove absence from the portal; it means portal registration/profile inclusion is not evidenced locally.
- A read-only Safari automation query stalled without returning page data and was terminated (exit 130). A named-profile `notarytool history` read exited 1 because the default Keychain was locked. Neither attempt returned or printed a secret.

## Readiness assessment

| Requirement | Status | Evidence / interpretation |
| --- | --- | --- |
| Legal entity and Team ID | EVIDENCED | Relux Works, LLC; Team ID `262RZ595FP`, corroborated by the accepted matrix, authenticated C1 team selection, and local signing identities. |
| App Review Guideline 5.4 organization eligibility | OPEN BLOCKER | Guideline 5.4 requires VPN apps to be offered by an organization. The legal entity is evidenced, but this audit did not retrieve the account's enrollment type or active paid-through date. This policy assessment is separate from technical portal access. |
| Current paid Apple Developer Program status | OPEN BLOCKER | Fresh team capability metadata and C1 portal access are positive technical signals, but Apple says expired memberships cannot access Certificates, Identifiers & Profiles. The authoritative Membership details status/expiration was not captured. |
| Required legal agreements | OPEN BLOCKER | Current Apple Developer Program License Agreement / Free Apps Agreement status was not captured. Paid Applications Agreement is conditional and is not a Gate P0 provisioning prerequisite unless the product will sell apps or offer In-App Purchases. |
| Network Extensions availability | EVIDENCED | Team-scoped Xcode metadata reports the capability public, editable, and not subject to a separate distribution approval request; development and Developer ID channels are listed. |
| Identifiers, certificates, profiles, devices access | PARTIALLY EVIDENCED | C1 confirms authenticated C&I&P access and matrix authority; existing signing identities and editable capability metadata corroborate access. The exact operator role and C&I&P permission grant were not captured, so least-privilege authorization is not closed. |
| Current Apple-silicon Mac inventory | LOCALLY EVIDENCED / PORTAL OPEN | One locally available Apple-silicon Mac is recorded by privacy-safe reference. Enabled registration in the Relux Works device list is not evidenced and no Relux Works Mac profile is cached. |
| Physical iPhone | DEFERRED — NEITHER PASS NOR FAILURE | ADR-024 defers iOS and the physical-iPhone row. Owner: `TASK-260715-1kntdx`. Resume action: an owner decision to start the iOS branch, which re-arms Gate A0 and the physical-iPhone requirements unchanged. This is not a macOS Gate P0 blocker. |

## Least-privilege role-to-action matrix

| Action | Minimum accountable role for this workflow | Named owner | Evidence / required state |
| --- | --- | --- | --- |
| Confirm organization enrollment, active membership, renewal, and accept updated Apple Developer Program agreements | Account Holder | Relux Works Account Holder | Apple assigns renewal and legal-agreement acceptance to the Account Holder. Record only organization enrollment type, status, and expiration/acceptance date. |
| View agreement status | Account Holder or Admin (Finance may view App Store Connect commercial agreements) | Relux Works Account Holder | DPLA status is authoritative in Membership / Agreements; commercial agreement status is authoritative in App Store Connect Business. |
| Register/configure the four macOS App IDs and enable Network Extensions | Admin with Certificates, Identifiers & Profiles access; Account Holder is an allowed fallback | Relux Works Apple Platform/CI Maintainer; execution task `TASK-260715-3jloqy` | Apple documents Account Holder or Admin for App ID registration and capability enablement. Admin is the least-privilege selected role. |
| Create/download the four Mac Development profiles | Admin with Certificates, Identifiers & Profiles access; Account Holder fallback | Relux Works Apple Platform/CI Maintainer; `TASK-260715-3jloqy` | Apple documents Account Holder or Admin for manual development profiles. |
| Register/enable the current Apple-silicon Mac | Admin with Certificates, Identifiers & Profiles access; Account Holder fallback | Relux Works Apple Platform/CI Maintainer; `TASK-260715-3jloqy` | Use the Mac provisioning UDID in the portal, but persist only the privacy-safe device reference and enabled status. |
| Maintain existing development certificate | Admin with Certificates, Identifiers & Profiles access | Relux Works Apple Platform/CI Maintainer | An Apple Development identity already exists and passed C1 signing. No new certificate is required by this audit. |
| Create a new Developer ID certificate if ever required | Account Holder; cloud-managed alternative requires its separately granted access | Relux Works Account Holder | Not required for Gate P0 because the current Developer ID Application identity exists. |
| Execute unattended portal mutations already authorized by C1 | Admin operator above, using the authenticated session granted in C1 | `TASK-260715-3jloqy` | Must apply exactly matrix `2026-07-28.r12`; forced reauthentication is recorded, not hidden. |

A plain Developer role is not selected for manual Gate P0 portal work: Apple's task-specific instructions for App IDs, capability changes, registered devices, and manual development profiles require Account Holder or Admin. The designated technical operator should therefore be Admin plus Certificates, Identifiers & Profiles access; legal and renewal powers remain with the Account Holder.

## Agreements

1. **Apple Developer Program License Agreement / Free Apps Agreement — required, status unknown.** Owner: Relux Works Account Holder. Resolution: open Membership details / Show Agreements, accept any updated terms, and record only `active/current` plus the acceptance or effective date.
2. **Paid Applications Agreement — conditional, not a Gate P0 technical prerequisite.** Owner: Relux Works Account Holder. Resolution: sign only if the approved commercial model includes paid distribution or In-App Purchases; track that later product/release decision separately.
3. **Network Extensions additional approval — no gap indicated.** The team-scoped capability record identifies Network Extensions as public/editable, `canRequestFromPortal=false`, and `distributionApprovalRequired=false`. This does not waive the program agreement or Guideline 5.4 organization requirement.

## Concrete blockers and external gaps

| ID | Gap / evidence | Owner | Resolution action |
| --- | --- | --- | --- |
| `APC34W-B1` | Apple Developer enrollment type and active paid-through date were not retrieved. | Relux Works Account Holder | In Membership details, confirm `Organization` enrollment and active membership/expiration. Persist only status and date; no account screenshot or contact data. |
| `APC34W-B2` | Current DPLA / Free Apps Agreement status was not retrieved. | Relux Works Account Holder | Review Show Agreements, accept any required update, then record privacy-safe status/effective date. |
| `APC34W-B3` | The authorized operator's exact Account Holder/Admin role and C&I&P permission grant were not captured. | Relux Works Account Holder | In App Store Connect Users and Access, confirm the Apple Platform/CI Maintainer is Admin with Certificates, Identifiers & Profiles access. Record functional role and grant state only. |
| `APC34W-B4` | The current Mac is locally available, but enabled Relux Works portal registration is not evidenced; no Relux Works Mac Development profile is cached. | Relux Works Apple Platform/CI Maintainer and `TASK-260715-3jloqy` | Verify or register the Mac with its provisioning UDID, then record only `device_ref=sha256:8ea3983a9990`, platform, and enabled status; include it in all four authorized Mac Development profiles. |
| `APC34W-B5` | The existing Safari session could not be observed unattended through the local automation bridge (stalled; terminated exit 130). | Ceremony C1 operator / local automation owner | Restore approved read-only browser automation or make a privacy-safe text export of Membership, Agreements, Users and Access, and Devices during an authenticated session. Do not store cookies, tokens, account screenshots, contact details, or full device IDs. |
| `APC34W-G1` | Physical-iPhone registration is deferred under ADR-024. | `TASK-260715-1kntdx` and product owner | On an explicit owner decision to resume iOS, re-arm the iOS branch and register/validate the physical iPhone. Until then report **deferred**, never pass or failure. |
| `APC34W-G2` | The default Keychain was locked during a named-profile validation read (exit 1). This does not alter the account verdict, but means unattended Keychain access was not continuously available. | `TASK-260728-dveo1o` and Ceremony C1 operator | Restore approved unattended login-Keychain access and rerun the named-profile authentication verification without echoing any credential or path. |

## Accountable next actions

1. Relux Works Account Holder closes `APC34W-B1`, `B2`, and `B3` with privacy-safe status fields.
2. The Apple Platform/CI Admin and `TASK-260715-3jloqy` close `APC34W-B4`, then create only the four authorized macOS identifiers/capabilities/profiles.
3. `TASK-260728-dveo1o` independently revalidates the named notarization profile after Keychain access is restored; no credential data is shared with this task.
4. `TASK-260715-1kntdx` remains blocked/deferred under ADR-024 until the product owner explicitly resumes iOS.

## Official policy sources consulted

- Apple App Review Guidelines 5.4: https://developer.apple.com/app-store/review/guidelines/
- Apple Developer Program roles: https://developer.apple.com/help/account/access/roles
- Program renewal and expired-membership effects: https://developer.apple.com/help/account/membership/renewal/
- Agreement status: https://developer.apple.com/help/app-store-connect/manage-agreements/view-agreements-status/
- Register an App ID: https://developer.apple.com/help/account/identifiers/register-an-app-id
- Enable app capabilities: https://developer.apple.com/help/account/identifiers/enable-app-capabilities
- Register a single device: https://developer.apple.com/help/account/devices/register-a-single-device
- Create a development provisioning profile: https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile/
- Developer ID certificates: https://developer.apple.com/help/account/certificates/create-developer-id-certificates/

## Validation applicability

- No product code, SwiftUI, Core Data, Go, build graph, certificate, identifier, profile, or architecture diagram was changed. Product tests, lint, builds, and diagram rendering are therefore not applicable.
- Repository changes are limited to the task's concise LOGBOOK entry; the readiness report is a board outcome.
- `git diff --check`: exit 0.
- `task-board validate`: exit 0, no issues.
- Task-outcome assertions: 13 required facts/sections found, exit 0.
- First privacy-classifier attempt: exit 1. Its credential pattern had invalid shell quoting and its 40-hex check incorrectly included the entire historical `LOGBOOK.md`, producing one unrelated historical match. It is not passing evidence.
- Corrected count-only privacy scan, scoped to this report plus only the newly added logbook lines: private-key headers 0; full 40-hex identifiers 0; full UUID-shaped identifiers 0; credential assignments 0; exit 0.
