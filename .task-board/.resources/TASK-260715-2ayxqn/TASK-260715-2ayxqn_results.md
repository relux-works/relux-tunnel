# TASK-260715-2ayxqn — macOS Gate P0 disposition

Recorded: 2026-08-19 (Asia/Tbilisi)

## Verdict

**PASS — Gate P0 passes for the macOS-only prototype target on the named physical Apple-silicon Mac.**

This is a two-row platform disposition under ADR-024: the physical Mac row is **PASS** and the physical-iPhone row is **DEFERRED — neither pass nor failure**. The iPhone row does not participate in the macOS pass calculation, and no iPhone result is inferred from Mac evidence. This verdict does not assert App Review/A0, iOS, App Store, notarization, production forwarding, or general release readiness.

The accountable owner completed the macOS system approval/install interactions and stated **“готово -- работай автономно”**. The owner-approved scope resource records that statement as authorization and acknowledgement for autonomous recording of this macOS P0 verdict and its downstream routing.

## Evidence routing

This report links the accepted board evidence without duplicating or fabricating its payloads.

- Owner-approved scope and acknowledgement: [macos-only-p0-disposition-scope.md](file://TASK-260715-2ayxqn/macos-only-p0-disposition-scope.md)
- Apple account readiness audit, including its explicitly retained release/account-assurance gaps: [TASK-260715-apc34w_results.md](file://TASK-260715-apc34w/TASK-260715-apc34w_results.md) and [accepted audit review](file://TASK-260715-apc34w/TASK-260715-apc34w_reviewer-verdict-01.md)
- Approved identity and entitlement matrix, revision `2026-07-28.r12`: [machine contract](file://TASK-260715-ypo7yo/TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.json), [rationale](file://TASK-260715-ypo7yo/TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.md), and [accepted revision-12 review](file://TASK-260715-ypo7yo/TASK-260715-ypo7yo_reviewer-verdict-11.md)
- Portal-derived App ID, capability, device, and profile metadata: [TASK-260715-3jloqy_results.md](file://TASK-260715-3jloqy/TASK-260715-3jloqy_results.md) and [accepted review](file://TASK-260715-3jloqy/TASK-260715-3jloqy_reviewer-verdict-01.md)
- Signed archive inspections: [build/inspection log](file://TASK-260715-1r0fxv/TASK-260715-1r0fxv_build-and-inspect.log), [probe result](file://TASK-260715-1r0fxv/TASK-260715-1r0fxv_results.md), and [accepted archive review](file://TASK-260715-1r0fxv/TASK-260715-1r0fxv_review.md)
- Physical Apple-silicon Mac evidence: [runbook](file://TASK-260715-9yp8to/TASK-260715-9yp8to_runbook.md), [result](file://TASK-260715-9yp8to/TASK-260715-9yp8to_results.md), [result bundle](file://TASK-260715-9yp8to/TASK-260715-9yp8to_result-bundle.zip), and [accepted independent review](file://TASK-260715-9yp8to/TASK-260715-9yp8to_review-verdict.md)
- Deferred iPhone gap: `TASK-260715-1kntdx`, with the ADR-024/ADR-027 evidence packet in its notes. The binding decision is `.spec/decisions.md` ADR-024.

## Explicit pass/fail accounting

| Row | Disposition | Evidence |
| --- | --- | --- |
| Account/team authority for this prototype | **PASS** | Accepted Ceremony C1 records an authenticated Certificates, Identifiers & Profiles session for Relux Works, LLC, Team `262RZ595FP`, and owner authority for the exact macOS-only r12 matrix. Later server-issued profiles, signing, and physical execution corroborate effective authority. |
| Identities, identifiers, capability, and profiles | **PASS** | Relux Works Apple Development signing succeeded. The four exact macOS App IDs received device-bound Mac Development profiles. Network Extensions is public/editable with no separate distribution approval request, and every profile contains the required unsuffixed `packet-tunnel-provider` authorization. No App Group or target Keychain Sharing entitlement was introduced. |
| Signed archive match | **PASS** | The host `works.relux.tunnel.probe.mac` and provider `works.relux.tunnel.probe.mac.tunnel` match team, identifiers, embedded profiles, App Sandbox, architecture, nesting, signatures, and r12 entitlements. Forty-nine inside-out checks passed; nine drift cases failed closed as designed. |
| Named physical Mac | **PASS** | Mac15,9 arm64, macOS 26.5 (25F71), Xcode 26.5 (17F42), source revision `9f65158f415beef5abcbeae32a007d3a266ae7df` with dirty-state disclosure. The provider installed and registered exactly once; one manager reloaded; ten cycles plus controlled reinstall launched the provider, returned the versioned v1 message with `packetForwarding=false`, and stopped cleanly. Final provider-process count was zero and no crash report was created. |
| macOS system-VPN approval | **PASS** | The owner completed the required system interaction; the subsequent accepted lifecycle and reinstall evidence passed without an unexplained approval or launch failure. |
| Physical iPhone | **DEFERRED** | ADR-024 defers iOS. `TASK-260715-1kntdx` remains blocked under ADR-027 until an owner decision resumes iOS. No iPhone profile, install, launch, message, stop, or pass is claimed. |
| Overall macOS Gate P0 | **PASS** | Every in-scope macOS install, profile, entitlement, portal-capability, launch, versioned-message, and stop requirement has accepted physical evidence. |

This is not a conditional pass. Any missing in-scope Mac evidence, profile or entitlement mismatch, unexplained lifecycle failure, expired profile, or unresolved Network Extensions/App-ID/profile approval would instead produce **FAIL or BLOCKED**. None is present in the accepted macOS evidence.

The earlier `TASK-260715-apc34w` audit remains accurately **NOT READY** for broader account/release assurance because it did not independently capture the membership paid-through date, current DPLA/Free Apps Agreement state, or the operator's exact Admin plus Certificates, Identifiers & Profiles grant. Those gaps are not silently closed or inferred. Under the owner-approved macOS prototype scope they are residual release/account risks, not unresolved in-scope P0 portal approval: authenticated r12 authority, exact server-issued profiles, successful signing/archive inspection, and physical provider execution directly establish the technical provisioning disposition. They must be closed before any later release gate that explicitly requires them.

## Expiry and mandatory revalidation

The four approved Mac Development profiles expire as follows:

- `works.relux.tunnel.mac`: 2027-08-10 19:28:44 UTC
- `works.relux.tunnel.mac.tunnel`: 2027-08-10 19:30:58 UTC
- `works.relux.tunnel.probe.mac`: 2027-08-10 19:31:26 UTC
- `works.relux.tunnel.probe.mac.tunnel`: 2027-08-10 19:31:50 UTC

The agreement effective/expiry date was not independently captured and is not invented here. Before a release gate that depends on account/agreement readiness, the Account Holder must record the current agreement and membership status plus effective/expiry dates. For this macOS P0 disposition, revalidation is mandatory after any profile expiration, renewal, replacement, or revocation; agreement or membership expiry/change that affects portal use; account role/grant change; device replacement or registration change; macOS, Xcode, or signing-identity change; bundle identifier, capability, entitlement, profile, nesting, version, or archive edit; system-VPN approval reset; or unexplained install/lifecycle regression. Repeat the affected readiness, matrix/profile/archive, and physical Mac install/launch/versioned-message/stop checks.

## Downstream disposition

After reviewer acceptance moves this task to `done`, this PASS clears only the `TASK-260715-2ayxqn` dependency edge for macOS-path consumers:

- `TASK-260715-32umrc` (record generated-project architecture ADR): its P0 edge clears, but it remains subject to `TASK-260715-1fv4z1`, `TASK-260715-3r0993`, and `TASK-260715-3bdplx`.
- `TASK-260715-1tzaed` (record macOS release identity, entitlement, and migration contract): its P0 edge clears, but it remains subject to `TASK-260715-32umrc`, `TASK-260715-uyju7n`, `TASK-260715-35nc5m`, and `TASK-260715-24icoz`.
- `TASK-260715-1u2vpc` is already `done`; its accepted owner-approved flow used `TASK-260715-9yp8to` as the technical prerequisite and no longer carries this task as a blocker.

Deferred branches remain blocked:

- `TASK-260715-3ikonq` remains behind the deferred ReluxNIOSSH/iOS-related branch and its other blockers; no physical-iPhone evidence is inferred.
- `TASK-260715-3661ps` remains on the deferred iOS/App Store path and behind its other blockers.
- `TASK-260715-1kntdx` remains the named deferred physical-iPhone gap under ADR-024/ADR-027.

No dependency was removed or weakened by this report; ordinary board dependency completion applies only after review acceptance.

## Traceability, residual risk, and completeness

- Gate definition: `.spec/platform-distribution.md` Gate P0 and `.spec/validation.md` P0 Provisioning.
- macOS-only physical rule and named deferred gap: `.spec/decisions.md` ADR-024 and ADR-027; `.spec/goal-macos-v1.md`.
- Owner acknowledgement sequencing: `.spec/decisions.md` ADR-028 and the task-scoped owner-approved scope resource.
- Accepted physical prerequisite: `TASK-260715-2ayxqn <- TASK-260715-9yp8to`; the prerequisite is `done`.
- Legacy checklist reconciliation: “account, identities, profiles, iPhone, and Mac” and “two-platform” are covered by explicit independent rows. The Mac passes; the iPhone is deferred rather than passed or omitted.
- Residual risks: account/agreement assurance remains a later release obligation; profiles expire in 2027; the accepted evidence is tied to the named Mac/OS/Xcode/source/signing/profile set; the disposable probe proves provisioning and lifecycle, not packet forwarding or production release fitness.
- No new Story, Task, Bug, research task, planning artifact, or diagram was needed. This single report is the smallest atomic deliverable for the five acceptance criteria, and no spec question remains open that warrants research.

Completeness result: all task acceptance criteria are addressed; every required evidence class is linked; Mac and iPhone are separately classified; expiry and revalidation triggers are explicit; accountable owner acknowledgement is recorded; and downstream clearing versus retained blockers is named.

## Validation

- Accepted source gates are linked above with their real exit codes; no failed result was rewritten as passing.
- This disposition changes evidence and logbook wording only; product code and architecture are unchanged, so product builds/tests are not applicable to this update.
- Final task-board validation and report assertion results are recorded in the task notes at handoff.
