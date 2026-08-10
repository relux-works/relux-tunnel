# TASK-260728-q5kjta Ceremony C1 outcome

Record finalized 2026-08-10T22:28:09+04:00. This timestamp is the evidence-record finalization time, not a fabricated human-session end time.

Contract amended 2026-08-10 after reviewer verdict 01. The owner explicitly selected Option B: accept resumed functional evidence and amend AC1, AC2, AC3, AC7, and ADR-028 while preserving the single human-input board node and every security/privacy prohibition. The amendment is recorded in the live task contract, `.spec/decisions.md` ADR-028, `.spec/goal-macos-v1.md`, `.spec/delivery.md`, and `LOGBOOK.md`.

## Session integrity and deviation

C1 began on 2026-07-28, with owner interaction resumed on 2026-08-10. Exact human-interaction start and end times were not captured. Producer and reviewer work occurred between those interactions. The original one-uninterrupted-session and exact-timing requirement was not satisfied, and reviewer verdict 01 correctly rejected that submission. The owner-approved amendment now accepts this honestly recorded resumed provenance under one ceremony board node. No uninterrupted-session claim, exact boundary, historical Always Allow click, or separately timestamped two-factor event is invented.

## Grants and authority recorded

- Login Keychain access was available. Prompt-free temporary signing probes succeeded through /usr/bin/codesign for Apple Development: Ivan Oparin (FSPBF3QRXT) and Developer ID Application: Relux Works, LLC (262RZ595FP). This demonstrates effective unattended private-key access for the named signing tool. A separate contemporaneous record of the Always Allow click was not captured, so the record does not invent one.
- The owner confirmed an authenticated Apple Developer Certificates, Identifiers and Profiles session with the selected Relux Works, LLC team and confirmed authority for the approved macOS-only matrix. Xcode account metadata was present. Two-factor completion was not separately timestamped; a fresh portal challenge remains a possible later forced interaction.
- Authorization is exactly revision 2026-07-28.r12: create works.relux.tunnel.mac, works.relux.tunnel.mac.tunnel, works.relux.tunnel.probe.mac, and works.relux.tunnel.probe.mac.tunnel; enable Network Extensions on all four, hosts included; create one Mac Development profile per App ID with this Apple-silicon Mac registered. TASK-260715-3jloqy performs those mutations later and unattended.
- Explicitly not authorized and not touched: works.relux.tunnel.ios, works.relux.tunnel.ios.tunnel, works.relux.tunnel.probe.ios, works.relux.tunnel.probe.ios.tunnel under ADR-024; works.relux.proxy; every Developer ID or App Store distribution profile; every App Group record; the App Groups capability on every App ID; and any Keychain access-group mutation. Rule G4 prohibits com.apple.security.application-groups on every macOS target. Rule K2 prohibits keychain-access-groups on every macOS target. Keychain sharing has no portal record.
- Named notarytool profile relux-works-notary was stored in the login Keychain. The owner disposition is RETAIN: the source App Store Connect API private-key file remains owner-controlled recovery material outside repository, board, and logs. It is not an automation credential. No file path, key ID, issuer ID, passphrase, or key bytes are recorded.
- The pinned Sparkle 2.9.4 vendor generate_keys tool generated the EdDSA keypair. Approved private-key custody location name: login Keychain. No private or public key material is recorded here.

No requested in-scope grant was declined, so no downstream decline blocker was added. Residual interaction: Apple may force fresh authentication or two-factor when TASK-260715-3jloqy performs portal mutations. Downstream tasks still own portal mutation/profile validation, notary authentication verification, and Sparkle public-key evidence.

## Privacy and history audit

Credential command echo was disabled according to the ceremony record. Targeted content scans checked private-key headers, App Store Connect key filenames or absolute key paths, literal notary credential arguments, and literal credential-variable assignments. Results: Git-scoped repository 0 candidate files and 0 key files; board resources 0 candidate files and 0 key files; run logs 0 candidate files; shell history 0 secret or credential candidate files. All targeted scan commands exited 0.

Full command-name history suppression cannot be claimed: the history contains one safe Sparkle generation command-name line and one safe Keychain-unlock command-name line, both with zero password flags. Neither contains a secret value, key path, key ID, issuer ID, account credential, or key bytes. Amended AC7 explicitly permits this harmless command-name-only history while keeping all secret-bearing content prohibited. A first byte-sensitive history classifier failed exit 2 and was rerun with LC_ALL=C at exit 0. Two optional broad gitleaks attempts were stopped for runtime at exit 130 and are not used as passing evidence.

The post-amendment targeted scan was rerun after the spec, board-contract, and outcome changes. Results: Git-scoped repository 0 candidate files and 0 key files; board resources 0 candidate files and 0 key files; run logs 0 candidate files; shell history 0 secret or credential candidate files. The combined scan exited 0. It emitted counts only, never candidate content.

## Validation and scope

- r12 matrix validator: 2862 checks, exit 0.
- Live board consumer gate: A1 28 checks, P1 20 checks, D1 41 checks, exit 0.
- git diff --check: exit 0.
- task-board validate: exit 0, no issues.
- Post-amendment privacy scan: exit 0, zero candidates in every required scope.
- Continuity wording audit: an overbroad classifier exited 1 because it counted the new clauses that explicitly prohibit an uninterrupted-session claim; the corrected forbidden-assertion scan exited 0.
- No product code changed. Product tests, SwiftUI/Core Data/Go tests, product lint, and product builds are not applicable.

Under the owner-amended live contract, AC1, AC2, AC3, and AC7 now pass on the recorded functional evidence and honest limitations. AC4-AC6 and AC8 remain unchanged and pass on the existing r12 authorization, named Keychain-backed custody, RETAIN disposition, decline/residual-interaction record, and downstream-task boundaries.

Important anomaly: historical TASK-260728-3a2dnr_ceremony-c1.md predates G4 and K2 and still names two macOS IDs plus App Group and Keychain grants. It is not executable authority. The live task contract and accepted r12 matrix control.
