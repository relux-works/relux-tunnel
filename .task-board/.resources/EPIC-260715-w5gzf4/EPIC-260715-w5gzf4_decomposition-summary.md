# EPIC-260715-w5gzf4 — M5 release and distribution decomposition

## Outcome

The five existing stories are development-ready at `to-dev`. The decomposition contains 67 atomic backlog tasks and 249 exact task dependency links. Every task has a clear title, description, explicit in-scope and out-of-scope boundary, five verifiable acceptance criteria, and three unchecked handoff checklist items including a task-ID-scoped outcome requirement.

No implementation, source, test, workflow, or specification content was changed. Board mutations and task-board planning/resources are the only project changes.

## Canonical phase plan

1. **Phase 1 — CI foundation:** STORY-260715-anxje6, 12 tasks.
2. **Phase 2 — Relay supply chain:** STORY-260715-19mjyn, 13 tasks.
3. **Phase 3 — Apple distribution in parallel:** STORY-260715-c1qsc6 macOS, 12 tasks; STORY-260715-243sh0 iOS, 12 tasks.
4. **Phase 4 — Release, privacy/legal, and App Review operations:** STORY-260715-2dtdql, 18 tasks.

The canonical story critical path is CI → relay supply chain → iOS distribution → release operations. macOS distribution runs in parallel with iOS after the accepted relay staging boundary. Exact upstream edges also consume Gate A0, Gate P0, generated targets, M1 routing disclosure, M2 relay conformance/assets, and M4 product/security acceptance.

## Story and task inventory

### STORY-260715-anxje6 — Least-privilege continuous integration and release quality gates (12)

- TASK-260715-2hef52 — Add board and specification validation as a required pull-request gate
- TASK-260715-1uxx3i — Add credential-free iOS and macOS host-extension build matrix
- TASK-260715-38atsq — Add secret, dependency, license, vulnerability, and SBOM gates
- TASK-260715-1m3edc — Add shared-core unit and protocol conformance CI
- TASK-260715-36gq4m — Add the relay release build and conformance CI matrix
- TASK-260715-vg2of8 — Exercise CI trust boundaries and release failure paths
- TASK-260715-2wjvlx — Harden GitHub Actions permissions, dependencies, and runner inputs
- TASK-260715-2ybl7y — Implement protected and serialized release orchestration
- TASK-260715-whtdsf — Record the CI trust boundary and required quality-gate contract
- TASK-260715-82zzad — Retain release artifact provenance and test evidence
- TASK-260715-3mk4hs — Validate generated workspace determinism and the preserved SwiftPM product
- TASK-260715-2759wy — Validate semantic versions, tags, bundle versions, and release notes

### STORY-260715-19mjyn — Reproducible relay supply chain, SBOM, and compliance evidence (13)

- TASK-260715-151xf0 — Assemble third-party notices and license evidence
- TASK-260715-3c06k7 — Audit relay source-to-staging integrity and compliance traceability
- TASK-260715-2pwg4j — Build the four declared relay release assets
- TASK-260715-1z8ac2 — Document relay update, rollback, and supply-chain incident operations
- TASK-260715-1lmmri — Enforce Apple bundle relay selection and integrity
- TASK-260715-nwcp1j — Enforce relay license, vulnerability, secret, and binary policy
- TASK-260715-1c4l9v — Execute the relay release-asset conformance and smoke matrix
- TASK-260715-37rtzn — Generate a machine-readable relay dependency SBOM
- TASK-260715-14flqo — Generate the release relay manifest and checksums
- TASK-260715-3e7noa — Pin relay release build environments and dependency inputs
- TASK-260715-28y0uc — Produce relay provenance attestations and the release staging bundle
- TASK-260715-pa6evr — Record the relay release input and reproducibility contract
- TASK-260715-3kepzm — Verify independent bit-for-bit relay build reproducibility

### STORY-260715-c1qsc6 — Signed, notarized, and recoverable macOS distribution (12)

- TASK-260715-30lksy — Assemble the macOS host-extension release archive
- TASK-260715-3gkwn0 — Configure Developer ID, notarization, and the protected macOS release environment
- TASK-260715-3s6yds — Create versioned and stable-name macOS DMG artifacts
- TASK-260715-yynqbr — Exercise macOS rollback, release withdrawal, and credential revocation
- TASK-260715-1gzhnk — Generate macOS checksums, provenance, and compliance evidence
- TASK-260715-3sk5cd — Implement inside-out hardened-runtime signing for the macOS archive
- TASK-260715-387eof — Notarize, staple, and Gatekeeper-validate the macOS candidate
- TASK-260715-1njthi — Publish versioned and stable macOS assets with authenticated GitHub access
- TASK-260715-1tzaed — Record the macOS release identity, entitlement, and migration contract
- TASK-260715-2aessv — Run the macOS signed-distribution acceptance matrix
- TASK-260715-1r48pc — Validate macOS clean install, upgrade, extension approval, and uninstall
- TASK-260715-go37ij — Verify macOS bundle topology, profiles, and entitlements

### STORY-260715-243sh0 — iOS archive, TestFlight, and App Store binary delivery (12)

- TASK-260715-1vo4rm — Allocate the iOS marketing version and monotonic build number
- TASK-260715-dsvvnu — Assemble and export the iOS App Store archive
- TASK-260715-8g5fpa — Configure App Store Connect and the protected iOS distribution environment
- TASK-260715-1quopg — Exercise TestFlight withdrawal, supersession, and credential revocation
- TASK-260715-3dno4w — Inspect iOS profiles, entitlements, bundle topology, and architectures
- TASK-260715-3ixjf7 — Produce the iOS distribution acceptance verdict
- TASK-260715-1lkgxh — Record iOS source-to-archive provenance and reproducibility evidence
- TASK-260715-3661ps — Record the iOS distribution, signing, version, and TestFlight contract
- TASK-260715-3a92td — Run the physical iPhone TestFlight VPN lifecycle matrix
- TASK-260715-sfkrzq — Upload, process, and distribute the TestFlight candidate
- TASK-260715-30ch0z — Validate iOS privacy manifests, symbols, APIs, and encryption inventory
- TASK-260715-1bni66 — Validate the exact App Store binary technical preflight

### STORY-260715-2dtdql — Release operations, privacy and legal compliance, and App Review submission (18)

- TASK-260715-11wjue — Assemble and audit the App Review submission package
- TASK-260715-2vhtqg — Audit privacy, legal, metadata, and App Review claims against the candidate
- TASK-260715-2dxzjv — Author reproducible App Review test instructions
- TASK-260715-zbd75q — Complete App Privacy labels, export compliance, and legal declarations
- TASK-260715-3rdsap — Execute the cross-platform release-candidate regression matrix
- TASK-260715-3c2ukn — Obtain the regional VPN licensing and storefront decision
- TASK-260715-1qwp3f — Prepare App Store metadata, screenshots, and support URLs
- TASK-260715-26wi46 — Prepare VPN data-flow, entitlement-purpose, and behavior evidence for App Review
- TASK-260715-1kpnkl — Provision an isolated App Review SSH test environment
- TASK-260715-2k812u — Publish the versioned public VPN privacy policy
- TASK-260715-29r0k8 — Record the release promotion, go or no-go, and ownership contract
- TASK-260715-312u2k — Record the release-readiness go or no-go decision
- TASK-260715-3cg87m — Revalidate current Apple review, privacy, export, and VPN requirements
- TASK-260715-2e6i0a — Submit the approved iOS candidate to App Review
- TASK-260715-13y6hb — Triage App Review feedback and govern resubmission
- TASK-260715-2y4gpx — Verify published channels and open the rollback watch
- TASK-260715-6j1u2g — Write the cross-platform release operations runbook
- TASK-260715-1g658s — Write the cross-platform rollback, incident, and credential-revocation runbook

## Cross-epic prerequisite boundaries

- TASK-260715-1828xy — Gate A0 disposition; release and review claims cannot reinterpret an ambiguous or negative Apple intended-use result.
- TASK-260715-2ayxqn — Gate P0 disposition; distribution identities require physical iPhone and Mac provisioning evidence.
- TASK-260715-32umrc, TASK-260715-33oofa, TASK-260715-uyju7n, and TASK-260715-nphtib — generated workspace, iOS/macOS targets, and architecture verification.
- TASK-260715-297gq6, TASK-260715-1q03sa, TASK-260715-mocqmr, TASK-260715-vtot05, and TASK-260715-u8tkx0 — protocol conformance and M2 portable-relay asset boundary.
- TASK-260715-1o4h97 — compatible routing, DNS, and Apple system-exclusion disclosure.
- TASK-260715-35nc5m and TASK-260715-1jtyre — approved legacy SOCKS disposition and migration/coexistence adapter.
- TASK-260715-2gwfaw, TASK-260715-3nzx7s, TASK-260715-1fk4ja, TASK-260715-1ets2m, TASK-260715-132kb2, and TASK-260715-zwtrhy — approved privacy copy, diagnostics/support acceptance, onboarding/accessibility/localization, physical VPN lifecycle, and final M4 product/security evidence.

## Explicit decision and research gates

- TASK-260715-whtdsf records the CI trust, permission, and required-check contract before workflow work.
- TASK-260715-pa6evr freezes relay release inputs and the true bit-for-bit reproducibility boundary.
- TASK-260715-1tzaed and TASK-260715-3661ps bind macOS and iOS release identities, profiles, entitlements, versions, and migration/channel semantics.
- TASK-260715-3gkwn0 and TASK-260715-8g5fpa establish least-privilege credential ownership, expiry, rotation, and revocation.
- TASK-260715-3cg87m revalidates current official Apple review, privacy, export, and VPN requirements before release.
- TASK-260715-3c2ukn requires accountable regional VPN licensing/storefront decisions; engineering assumption cannot close it.
- TASK-260715-2k812u and TASK-260715-zbd75q require approved public privacy policy, App Privacy, export, and legal declarations.
- TASK-260715-1kpnkl provides the isolated, expiring, non-production App Review SSH fixture.
- TASK-260715-312u2k is the evidence-backed go, hold, or reject boundary before production publication or submission.

## Requirement coverage

| Requirement | Primary tasks |
| --- | --- |
| Least-privilege CI and untrusted PR isolation | TASK-260715-whtdsf, TASK-260715-2wjvlx, TASK-260715-2ybl7y, TASK-260715-vg2of8 |
| Shared core, Apple, relay, board/spec, security gates | TASK-260715-2hef52, TASK-260715-3mk4hs, TASK-260715-1m3edc, TASK-260715-1uxx3i, TASK-260715-36gq4m, TASK-260715-38atsq |
| Semantic versions, release notes, provenance, retention | TASK-260715-2759wy, TASK-260715-82zzad |
| Relay pinning and four-target reproducibility | TASK-260715-pa6evr through TASK-260715-3kepzm |
| Relay manifest and Apple-bundle integrity | TASK-260715-14flqo, TASK-260715-1lmmri, TASK-260715-3c06k7 |
| SBOMs, notices, vulnerability/license evidence | TASK-260715-37rtzn, TASK-260715-151xf0, TASK-260715-nwcp1j |
| macOS entitlements, nested signing, hardened runtime | TASK-260715-1tzaed, TASK-260715-go37ij, TASK-260715-3sk5cd |
| macOS notarization, stapling, Gatekeeper, stable authenticated assets | TASK-260715-387eof, TASK-260715-1njthi, TASK-260715-2aessv |
| iOS profiles, entitlements, TestFlight, physical lifecycle | TASK-260715-3dno4w, TASK-260715-sfkrzq, TASK-260715-3a92td, TASK-260715-3ixjf7 |
| Honest Apple signed-output reproducibility | TASK-260715-1lkgxh and macOS provenance TASK-260715-1gzhnk |
| Public privacy, App Privacy, export, regional/legal | TASK-260715-3cg87m, TASK-260715-3c2ukn, TASK-260715-2k812u, TASK-260715-zbd75q |
| App Review evidence, fixture, instructions, metadata, submission | TASK-260715-26wi46, TASK-260715-1kpnkl, TASK-260715-2dxzjv, TASK-260715-1qwp3f, TASK-260715-11wjue, TASK-260715-2e6i0a |
| Runbooks, rollback, withdrawal, credential revocation | TASK-260715-1z8ac2, TASK-260715-yynqbr, TASK-260715-1quopg, TASK-260715-6j1u2g, TASK-260715-1g658s |
| Exact-candidate regression, behavior-to-claim audit, go/no-go | TASK-260715-3rdsap, TASK-260715-2vhtqg, TASK-260715-312u2k |

## Planning artifacts

- EPIC-260715-w5gzf4_canonical-plan.md — task-board saved four-phase plan.
- EPIC-260715-w5gzf4_release-dependency.dot — story and upstream dependency diagram source.
- TASK-260715-whtdsf_ci-trust-boundary.puml — untrusted PR versus protected release trust boundary.
- TASK-260715-1tzaed_macos-release-sequence.puml — macOS archive, signing, notarization, publication, and install sequence.
- TASK-260715-3661ps_ios-testflight-sequence.puml — version, archive, TestFlight, physical acceptance, and handoff sequence.
- TASK-260715-29r0k8_release-gate-dependency.dot — detailed release, legal, review, and go/no-go dependency graph.
- EPIC-260715-w5gzf4_logbook.md — architectural findings and decisions.
- EPIC-260715-w5gzf4_diagram-render-validation.md — renderer anomaly and validation record.

Graphviz image rendering is not currently available because the installed dot binary cannot load Homebrew libltdl.7.dylib. The board graph and diagram source are valid and preserved; repairing that workstation dependency is not a product blocker.

## Verification

- `task-board validate`: board is valid with no issues.
- Canonical epic plan: five stories, four phases, no dependency cycle.
- Task-level plans: all five stories produce acyclic phased plans.
- Completeness audit: 67 tasks; zero missing titles, descriptions, in/out scope, numbered AC, checklists, task-ID-scoped outcome clauses, or backlog statuses.
- Story audit: all five stories have complete title, description, in/out scope, six numbered acceptance criteria, children, `to-dev` status, and no retained planning-agent assignment.
- All tasks remain unstarted in backlog.

## Remaining external decisions

Planning has no unresolved structural question. Execution remains intentionally blocked on upstream Gate A0/P0 and M2/M4 evidence plus the explicit CI trust, release credential, legacy migration, current Apple rules, regional legal/storefront, privacy/export, and review-fixture tasks listed above. Those tasks state the required owner, evidence, pass condition, and downstream impact.
