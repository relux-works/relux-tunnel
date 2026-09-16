# TASK-260715-intsjz — launch-localization decision and handoff

Decision date: 2026-08-30

Status: solution-architecture decision ready for review. The task notes preserve an owner decision dated 2026-08-10: the first macOS release is English-only; Ivan/Relux Works owns source, privacy, and security copy; translations and RTL launch support are deferred. This artifact normalizes that approved direction into a dev-ready contract and defines the approval boundary for adding locales. It does not produce translations, implement localization, decide storefront availability, or host public policy.

## 1. Launch decision

- Source/development localization: `en`; source copy follows U.S. English spelling and terminology (`en-US` editorial convention).
- Exact shipping UI locale list for the baseline: **[`en`]**. There is no separately translated `en-US` catalog and no non-English shipping catalog.
- Every user-visible and accessibility string must nevertheless resolve from the approved String Catalog (or a later explicitly approved equivalent). No source-language literals may bypass the catalog.
- Locale resolution chain: requested system/app language -> exact shipping locale match -> shipping base-language match -> development localization `en`. With the baseline list, every unsupported language resolves to `en`; missing resources or unreadable catalogs are errors, not an “unsupported locale” fallback.
- English regional variants such as `en-GB` use the `en` copy. Dates, times, numbers, measurements, and plural selection use Foundation locale-aware formatters with the user's current formatting locale; they are not hand-formatted into English strings.
- The English-only launch is not blocked on a translation owner. Adding any locale is blocked until the Localization DRI, native linguistic reviewer, Product Owner, Privacy/Legal Approver, Accessibility Reviewer, and Release Manager are recorded and approve the exact copy version. An unapproved translation may exist only in non-shipping fixtures.
- Right-to-left shipping languages are explicitly deferred because none is in [`en`]. RTL readiness is not deferred: a pseudo-RTL lane is mandatory now. An unsupported RTL system language receives the English LTR localization; real RTL shipping requires native review and a revised locale list.

## 2. Ownership and approval ledger

The owner names below use the persisted owner decision plus accountable release roles tied to concrete board work. Where the owner decision did not name a person, the board assignee/review record is the identity evidence; no identity is invented.

| Concern | Accountable owner / record | Required approval and trigger |
| --- | --- | --- |
| Source product copy | **Ivan/Relux Works**, exercised through `TASK-260715-2gwfaw` | Approves the versioned English copy deck; rereview on wording, claim, flow, CTA, error, or support change |
| Privacy/legal copy and link meaning | **Ivan/Relux Works** owns privacy copy; the accountable Privacy/Legal review is recorded in `TASK-260715-2gwfaw` | Approves every privacy/retention/export/security-sensitive key and destination purpose; rereview on data flow, retention, telemetry, policy URL, regional requirement, or claim-state change. This record is ownership, not legal advice |
| SSH/security terminology | **Ivan/Relux Works** owns security copy; Security Reviewer applies `.spec/security-claims.md` claim IDs | Approves glossary, limitations, fingerprint/host-key wording, degraded/fail-closed claims, and link mapping; rereview on architecture/evidence-state/security-term change |
| Translation production | **Deferred / no owner assigned**, by the 2026-08-10 owner decision | No translated product copy may be produced or shipped. Before adding a locale, Ivan/Relux Works must name a Localization DRI and native linguistic reviewer in `TASK-260715-1ets2m`; they then own provenance and catalog delivery |
| Native linguistic review | Native Linguistic Reviewer recorded per proposed locale in `TASK-260715-1ets2m` | Reviews meaning, grammar, placeholders, plurals, technical terms, screenshots, and sensitive copy at the same source-copy version |
| Accessibility language/pronunciation | Accessibility Reviewer in `TASK-260715-1fk4ja`, with physical acceptance in `TASK-260715-zwtrhy` | Approves labels, hints, announcements, reading order, and pronunciation; rereview on accessibility text, terminology, or primary-flow change |
| Launch list and product priority | **Ivan/Relux Works**, approved in task notes on 2026-08-10 | Owns [`en`] or a later explicit revision; adding/removing a locale requires a versioned decision update, never an implicit catalog discovery |
| Release parity and handoff | **Ivan/Relux Works Release Owner**, operational evidence consumed by `TASK-260715-1qwp3f` | Blocks candidate when catalogs, screenshots, metadata, policy links, approvals, or copy versions disagree; a different acting release manager must be named in the board record |

Execution assignees do not self-approve their own translation or sensitive copy. Privacy/security strings need both native linguistic review and the applicable Privacy/Legal or Security approval after translation.

## 3. Catalog and content rules

1. Stable semantic keys are version-controlled. Renaming a key is a migration with explicit old-key removal evidence, not a silent delete/add.
2. Variables use typed interpolation/placeholders. Whole sentences are localized; fragments are not concatenated. Placeholder name, type, cardinality, and allowed markup must match the source entry.
3. Plurals use String Catalog plural variations. Code must pass the numeric value, not select an English singular/plural branch.
4. Dates, times, and numbers use locale-aware Foundation formatting. Protocol values that are intentionally invariant (ports, opaque error codes, SSH fingerprints) use their canonical format and are visually/accessibly isolated from surrounding prose.
5. `SSH`, `VPN`, `DNS`, `TCP`, and `UDP` remain glossary-controlled technical terms and are pronounced letter-by-letter in accessibility copy. `QUIC` uses the reviewed product pronunciation. “Host key,” “fingerprint,” “exit host,” “full,” “degraded,” “compatible,” and “fail-closed” may not be translated without the translator comment and security review. Credentials, keys, and fingerprints are never expanded into speech beyond the approved safe representation.
6. Translator context includes screen/state, audience, safety consequence, claim ID when applicable, variable examples with synthetic values, character/line pressure, screenshot reference, pronunciation, and whether the string is a control, status, error, or disclosure.
7. Link labels are localized; destination URLs are selected through versioned semantic link IDs, never embedded in translations. A locale-specific target must be separately approved and reachable. Otherwise the approved English target is used with English fallback copy; a read failure is not treated as “localized target absent.”
8. Each sensitive source-copy set carries a monotonically increasing copy version. Every shipping catalog, in-app disclosure, accessibility equivalent, screenshot set, store metadata set, and linked policy/support artifact records the same required version or the release gate fails.
9. A missing key, unreadable/malformed catalog, empty required value, placeholder mismatch, stale shipping translation, unapproved locale, or copy-version mismatch fails CI and release validation. Production must not show raw keys, silently reuse stale sensitive text, or fall back because a catalog read failed.
10. Non-shipping locale material is excluded from the shipping locale declaration and cannot satisfy locale acceptance. Machine translation may be used only as a labeled test fixture, never as approved product copy.

## 4. Layout, RTL, and accessibility policy

- Pseudo-localization includes accented glyphs, at least 30% general expansion, a 50% stress fixture for short controls/statuses, and pseudo-RTL mirroring/isolation.
- Critical evidence, safety limitations, state, errors, and primary actions must not truncate. Scrolling/wrapping is allowed where interaction and reading order remain intact; shrinking below accessible platform text sizes is not.
- Bidirectional user values such as hosts, accounts, IPs, ports, codes, and fingerprints are isolated as values without forcing the whole localized sentence to LTR.
- Accessibility labels/hints/announcements are catalog entries with the same copy version. VoiceOver must announce state changes and errors once, preserve secure-field privacy, and speak abbreviations/technical values according to the glossary.
- A real RTL locale cannot ship on pseudo-RTL evidence alone. It requires a native reviewer and full locale matrix.

## 5. Platform acceptance matrix

| Gate | macOS 15+ M4 row | iOS 18+ row (deferred by ADR-024, re-arms unchanged) | Pass evidence / owner |
| --- | --- | --- | --- |
| Pseudo-localization | Launch accented +30%, 50% stress, and pseudo-RTL through onboarding, trust/auth, connect, full/degraded/reasserting/failure, diagnostics/export/delete, settings, and legacy-decision UI | Same states when iOS resumes; no result inferred from Mac | Deterministic launch configuration, state matrix, no missing/raw keys or critical clipping; `TASK-260715-1ets2m` |
| Long-text expansion | Keyboard and pointer paths remain usable at supported text scaling; controls, menus, sheets, alerts, and status evidence wrap/scroll correctly | Dynamic Type through supported accessibility sizes; rotation/safe-area layouts when applicable | Snapshot/layout assertions plus human visual inspection; `TASK-260715-1ets2m` and `TASK-260715-1fk4ja` |
| Locale launch/fallback | Launch `en`, `en-GB`, and one unsupported non-English system language; all resolve to `en` copy while dates/numbers follow the formatting locale | Same launch arguments/settings after iOS resumes | Runtime locale report, catalog version, screenshots, and negative missing/unreadable-resource cases; `TASK-260715-1fk4ja` |
| Screenshots | Review all critical states in `en` plus pseudo expansion/RTL; redact synthetic host/account/fingerprint data | Same required device classes after iOS resumes | Exact build/environment, screenshot manifest and diffs, human visual verdict; `TASK-260715-1fk4ja`, consumed by `TASK-260715-1qwp3f` |
| Accessibility | VoiceOver + keyboard completes primary journey; labels, headings, focus, announcements, glossary pronunciation, scaling, contrast, and reduced motion pass | VoiceOver completes the primary journey when iOS resumes; Switch Control/external keyboard coverage follows the UI-test task contract | Accessibility transcript/checklist and redacted screenshots; `TASK-260715-1fk4ja`, physical acceptance `TASK-260715-zwtrhy` |

## 6. Negative evidence required downstream

This decision does not ship a gate. A bounded source scan found no current `String(localized:)`, `LocalizedStringKey`, `NSLocalizedString`, String Catalog, stringsdict, `developmentRegion`, or `knownRegions` call site in `App/`, `Sources/`, `Tests/`, `Project.swift`, `Workspace.swift`, or `Package.swift`. Therefore the production localization entry point is **not yet implemented**, not merely unreadable. `TASK-260715-1ets2m` must name the real runtime catalog resolver and CI/release validation call sites when it creates them.

The downstream gate must include positive launch evidence and negative cases that drive those real entry points:

- delete one required `en` key -> build/validation fails, while deleting only an unused fixture key does not prove the bound;
- corrupt or make the catalog unreadable -> hard read failure, never unsupported-locale fallback;
- mismatch placeholder name/type/count -> validation fails;
- set a shipping translation behind the current copy version -> validation fails;
- enable a locale without the complete approval/provenance record -> release validation fails;
- mismatch privacy/accessibility/store/policy copy versions or semantic link target -> release validation fails;
- supply self-authored approval metadata or pseudo-locale evidence as native approval -> validation rejects it;
- bypass the catalog with a visible literal -> source/CI check fails and a runtime journey proves the catalog resolver is actually called.

The prompt referenced `references/negative-evidence.md`, but no such file was present under the installed `.agents`, `.claude`, or `.codex` skill roots during this run. That is recorded as an unavailable reference, not inferred content; the explicit negative-evidence rules embedded in the task assignment were applied.

## 7. Downstream trace and release handoff

- `TASK-260715-2gwfaw` supplies approved, versioned English privacy/support source copy and sensitive-copy approvals.
- `TASK-260715-1ets2m` is already blocked by this task and implements the catalog, fallback, translator context, parity gate, pseudo-localization, RTL-readiness fixtures, and negative tests.
- `TASK-260715-1fk4ja` is already blocked by `TASK-260715-1ets2m` and owns cross-platform locale, screenshot, and accessibility UI journeys. Its iOS execution remains explicitly deferred under ADR-024.
- `TASK-260715-zwtrhy` consumes feasible locale/pseudo/accessibility rows in final physical M4 acceptance.
- M5 `TASK-260715-1qwp3f` is already blocked by `TASK-260715-1ets2m` and owns release screenshots, metadata locale variants, and support/privacy URL parity.

No new story/task/research node or dependency was created: the existing DAG covers the decision -> implementation -> UI acceptance -> M5 handoff, and the specification leaves no technical research question open. Adding a direct edge to M5 would duplicate the existing transitive gate.

## 8. Approval/disposition

Approved owner direction: [`en`] for the first macOS release. Expanding the launch list is refused until the full owner and approval record above exists. Review of this task accepts the normalized fallback/validation/handoff contract; source privacy/security copy still cannot ship until `TASK-260715-2gwfaw` is approved. If Ivan/Relux Works supersedes English-only launch, the precise required input is: a versioned replacement locale list plus a Localization DRI and native reviewers for every added locale. No translation is guessed in the meantime.

## 9. Acceptance-criteria verification

- AC1: exact locale list, source language, system behavior, and fallback chain are in section 1.
- AC2: all six requested owner classes plus security/native review and update triggers are in section 2.
- AC3: variables, plurals, formats, security terms, links, keys, staleness, RTL, and copy parity are in sections 3-4.
- AC4: pseudo, expansion, locale launch, screenshot, and accessibility rows for macOS and deferred iOS are in section 5.
- AC5: selected baseline/expansion refusal and exact downstream M4/UI/M5 tasks are in sections 7-8.

## 10. Commands and evidence

- `task-board m 'set_status(TASK-260715-intsjz, status=analysis)'` -> exit 0.
- Targeted `project_config(view=spawn-preflight, role=solution-architect)` plus TASK/Story reads -> exit 0. A later notes mutation read back the pre-existing 2026-08-10 owner decision; this artifact was revised to include it rather than treating owner identity as unknown.
- Exact worktree/base check: branch `task-board/story/STORY-260716-2mtjdn`; `HEAD`, local `main`, and `origin/main` all resolved to `b3422b05226253a17676b9b84c764071fe3dbe74` -> exit 0; no branch switch/rebase/merge occurred.
- Targeted spec scan used `.spec/product.md`, `.spec/security-privacy.md`, `.spec/security-claims.md`, `.spec/validation.md`, `.spec/platform-distribution.md`, `.spec/delivery.md`, and `.spec/decisions.md` -> exit 0.
- Board reads verified existing downstream tasks and dependency edges -> exit 0.
- Bounded localization call-site scan returned zero matches in the named source/test/project paths -> scan command exit 0 via explicit no-match handling; the raw first probe exited 1 because it combined two legitimate no-match searches.
- Installed-skill lookup returned zero `references/negative-evidence.md` paths; content remains unavailable/unknown rather than inferred.
- `task-board validate` -> exit 0, but reported one unrelated pre-existing issue: `PARENT_STATUS_MISMATCH` for `STORY-260715-1y04r0` (`to-dev` vs child aggregate `reviewing`). It is not treated as a clean board and is outside this task's localization scope.
- `git diff --check` -> exit 0; final `git status --short` was empty. This decision produced board evidence only and no repository delta.

Residual risks: no Translation DRI or native linguistic reviewer is assigned because translated/RTL launch is deferred; that is a hard expansion gate, not permission to guess translations. Acting accessibility and release reviewers must be recorded by their downstream board runs. English-only reduces translation risk but does not remove source-copy, accessibility, screenshot, public-link, or regional-release gates. iOS evidence remains deferred and must not be inferred from macOS. The unrelated `STORY-260715-1y04r0` aggregate mismatch remains for its owner.

## Logbook record

2026-08-30 — Normalized the persisted 2026-08-10 Ivan/Relux Works owner decision: `en` is the sole baseline shipping UI locale, with U.S.-English source conventions, deterministic `en` fallback, user-locale formatting, mandatory catalog externalization/pseudo/RTL readiness, and fail-closed missing/stale/parity rules. Non-English launch is gated on naming localization/native reviewers and completing privacy/security/accessibility/product/release approvals. Existing tasks `1ets2m -> 1fk4ja -> 1qwp3f` carry implementation, UI evidence, and M5 handoff; no extra board node or diagram is justified.
