# TASK-260715-2ayxqn — macOS Gate P0 disposition

Recorded: 2026-08-11 (Asia/Tbilisi)

## Verdict

**BLOCKED — the physical Apple-silicon Mac row passes, but Gate P0 cannot receive a conditional pass while accepted account-readiness prerequisites remain unverified.**

This verdict is macOS-only under ADR-024. The physical-iPhone row is **DEFERRED — neither pass nor failure** and does not cause this blocked verdict. No Mac result is inferred as iPhone evidence.

The accountable owner completed the required system approval/install interactions and stated **“готово -- работай автономно”**. The owner-approved scope resource treats that statement as authorization and acknowledgement for autonomous recording of the resulting verdict and downstream routing.

## Evidence routing

This report links existing evidence and does not duplicate or fabricate its payloads.

- Owner-approved scope and acknowledgement: [macos-only-p0-disposition-scope.md](file://TASK-260715-2ayxqn/macos-only-p0-disposition-scope.md)
- Apple account readiness audit: [TASK-260715-apc34w_results.md](file://TASK-260715-apc34w/TASK-260715-apc34w_results.md) and [accepted audit review](file://TASK-260715-apc34w/TASK-260715-apc34w_reviewer-verdict-01.md)
- Approved identity and entitlement matrix, revision 2026-07-28.r12: [machine contract](file://TASK-260715-ypo7yo/TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.json), [rationale](file://TASK-260715-ypo7yo/TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.md), and [accepted revision-12 review](file://TASK-260715-ypo7yo/TASK-260715-ypo7yo_reviewer-verdict-11.md)
- Portal-derived App ID, capability, device, and profile metadata: [TASK-260715-3jloqy_results.md](file://TASK-260715-3jloqy/TASK-260715-3jloqy_results.md) and [accepted review](file://TASK-260715-3jloqy/TASK-260715-3jloqy_reviewer-verdict-01.md)
- Signed archive inspections: [build/inspection log](file://TASK-260715-1r0fxv/TASK-260715-1r0fxv_build-and-inspect.log), [probe result](file://TASK-260715-1r0fxv/TASK-260715-1r0fxv_results.md), and [accepted archive review](file://TASK-260715-1r0fxv/TASK-260715-1r0fxv_review.md)
- Physical Apple-silicon Mac evidence: [runbook](file://TASK-260715-9yp8to/TASK-260715-9yp8to_runbook.md), [result](file://TASK-260715-9yp8to/TASK-260715-9yp8to_results.md), [result bundle](file://TASK-260715-9yp8to/TASK-260715-9yp8to_result-bundle.zip), and [accepted independent review](file://TASK-260715-9yp8to/TASK-260715-9yp8to_review-verdict.md)
- Deferred iPhone gap: `TASK-260715-1kntdx`, with its ADR-024/ADR-027 evidence packet in task notes. The binding decision is `.spec/decisions.md` ADR-024.

## Platform accounting and explicit criteria

| Row | Disposition | Evidence |
| --- | --- | --- |
| Named physical Mac | **PASS** | Mac15,9 arm64, macOS 26.5 (25F71), Xcode 26.5 (17F42). The signed host/provider installed; PlugInKit exposed exactly one provider; one manager reloaded; ten cycles and a controlled reinstall launched the provider, returned the versioned v1 message with `packetForwarding=false`, and stopped cleanly. Final provider-process count was zero and no crash report was created. |
| Mac signing/profile match | **PASS** | Team `262RZ595FP`; host `works.relux.tunnel.probe.mac`; provider `works.relux.tunnel.probe.mac.tunnel`; exact Apple Development signatures, profiles, App Sandbox, and unsuffixed `packet-tunnel-provider` entitlement. Forty-nine inside-out checks and nine drift cases passed/fail-closed. |
| macOS system approval | **PASS** | The accepted physical run followed the owner-completed VPN approval interaction and all required lifecycle operations subsequently passed. |
| Physical iPhone | **DEFERRED** | ADR-024 defers iOS. `TASK-260715-1kntdx` remains blocked under ADR-027 and re-arms unchanged only after an explicit owner decision to resume iOS. No profile, install, launch, message, stop, or pass is inferred from Mac evidence. |
| Overall Gate P0 | **BLOCKED** | The accepted readiness audit remains operationally NOT READY: organization enrollment/active paid-through date (APC34W-B1), current DPLA/Free Apps Agreement status (B2), and the accountable Admin plus Certificates, Identifiers & Profiles grant (B3) were not captured. AC3 requires blocked/fail, not conditional pass, for missing in-scope evidence or unresolved portal/account approval. |

A future **PASS** requires both: (1) the already-passing Mac install/launch/versioned-message/stop evidence remains valid; and (2) B1-B3 are closed with privacy-safe authoritative status fields. Any absent Mac evidence, entitlement/profile mismatch, unexplained lifecycle failure, expired profile, or unresolved capability/portal approval is **FAIL or BLOCKED**. The deferred iPhone row never participates in the macOS pass calculation.

## External blocker packet

- Constraint: the Account Holder-only membership/agreement facts and accountable access grant are not in accepted evidence.
- Evidence: the accepted account audit and reviewer verdict explicitly preserve APC34W-B1 through B5 and state that the operational conclusion is NOT READY. Later provisioning closes the Mac registration/profile substance of B4, and the physical run closes the Mac signing/approval/lifecycle substance, but no board evidence closes B1-B3.
- Failed attempt: bounded read-only Safari observation did not return portal data (audit exit 130; later provisioning observation exit 142). Successful server-issued profiles are strong technical capability evidence but do not state the paid-through date, current agreement state, or operator role/grant.
- Options:
  1. Recommended: Account Holder records only organization enrollment type, active membership and expiry, current DPLA/Free Apps Agreement state/effective date, and confirms the functional Admin with C&I&P access. Then revise this disposition against unchanged Mac evidence if no revalidation trigger fired.
  2. Decline or defer those confirmations: keep Gate P0 and its macOS-prototype consumers blocked.
- Exact external input required: privacy-safe authoritative values for B1-B3 from Membership/Agreements/Users and Access; no credentials, screenshots, contact data, tokens, or full device identifiers.

## Expiry and revalidation

The four approved Mac Development profiles expire on 2027-08-10:

- `works.relux.tunnel.mac`: 2027-08-10 19:28:44 UTC
- `works.relux.tunnel.mac.tunnel`: 2027-08-10 19:30:58 UTC
- `works.relux.tunnel.probe.mac`: 2027-08-10 19:31:26 UTC
- `works.relux.tunnel.probe.mac.tunnel`: 2027-08-10 19:31:50 UTC

Agreement and paid-membership expiry/effective dates are not captured; this is a blocker, not a presumed date. Revalidation is mandatory after any profile or agreement expiration/renewal/update; paid-program or role/grant change; device replacement or registration change; macOS/Xcode/signing-identity change; bundle identifier, capability, entitlement, profile, nesting, version, or archive edit; system VPN approval reset; or unexplained install/lifecycle regression. Revalidation must repeat readiness evidence, exact matrix/profile/archive inspection, and the physical Mac install/launch/versioned-message/stop path as applicable.

## Downstream disposition

No downstream task is unblocked by a blocked overall Gate P0 verdict.

- Mac-path consumers `TASK-260715-32umrc`, `TASK-260715-1u2vpc`, and `TASK-260715-1tzaed` keep the `TASK-260715-2ayxqn` gate edge and remain subject to their other blockers.
- `TASK-260715-3ikonq` is not unblocked: its retained physical-iPhone provider-smoke wording belongs to the deferred iOS/ReluxNIOSSH branch and cannot be satisfied or inferred from this Mac result.
- `TASK-260715-3661ps` remains on the deferred iOS/App Store path and is not unblocked by a macOS disposition.
- Once B1-B3 are authoritatively closed and this report is revised to PASS, only the macOS-path consumers may clear this specific edge; every other dependency and all deferred-iOS blockers remain intact.

## Traceability and completeness audit

This single report is the smallest atomic deliverable for the five task acceptance criteria; no new Story, Task, Bug, research task, diagram, or planning artifact was needed.

- Gate definition: `.spec/platform-distribution.md` (“Gate P0”) and `.spec/validation.md` (“P0 Provisioning”).
- macOS-only platform rule and named deferred gap: `.spec/decisions.md` ADR-024 and ADR-027; `.spec/goal-macos-v1.md`.
- Owner sign-off sequencing and downstream ordering: `.spec/decisions.md` ADR-028 and `.spec/delivery.md`.
- Existing dependency into this task: `TASK-260715-2ayxqn <- TASK-260715-9yp8to`; accepted Mac evidence is present and `done`.
- Existing deferred-gap record: `TASK-260715-1kntdx` names the gap, deciding ADRs, why it is blocked rather than schedulable, and the exact owner decision needed to resume.
- Beyond-literal legacy checklist handling: owner-approved `macos-only-p0-disposition-scope.md` explicitly checked the legacy iPhone/two-platform wording against ADR-024. The report accounts for iPhone as deferred without creating evidence or requiring a pass.
- No open research question exists: the missing B1-B3 facts require authoritative Account Holder evidence, not research.
- The fail-closed discrepancy and revalidation rule are recorded in `LOGBOOK.md`.

Completeness result: every task AC is addressed, every linked evidence class is present, the Mac and deferred-iPhone rows are independently classified, dependencies are identified, and the unresolved external input is explicit.