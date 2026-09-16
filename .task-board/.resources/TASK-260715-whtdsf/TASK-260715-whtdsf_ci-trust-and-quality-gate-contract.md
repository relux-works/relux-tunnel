# TASK-260715-whtdsf — CI trust and quality-gate contract

Status: binding autonomous draft; independent agent verdicts are retained as
task outcomes, and later human ratification remains tracked at
`TASK-260717-2d308k`.

Authority: `.spec/platform-distribution.md` §CI/CD, `.spec/validation.md`,
`.spec/security-privacy.md`, `.spec/threat-model.md`, `.spec/delivery.md`,
ADR-013/016/017/018/019/024/027/029, and
`docs/TASK-260715-32umrc_generated-project-architecture-adr.md`.

Focused trust-boundary view:
[`TASK-260715-whtdsf_ci-trust-boundary.puml`](../diagrams/TASK-260715-whtdsf_ci-trust-boundary.puml)
([rendered SVG](../diagrams/artefacts/TASK-260715-whtdsf_ci-trust-boundary.svg)).

## 1. Scope and non-claims

This contract governs credential-free pull-request validation for the
macOS-first prototype and the protected macOS/relay release path. It defines
workflow boundaries and blocking check names; it does not implement GitHub
Actions.

- Gate A0 is not an input to prototype CI. It re-arms before iOS submission or
  any public distribution claim that depends on App Review acceptance.
- No Linux CI runner is required for the working-client path. The relay's four
  declared Darwin/Linux, amd64/arm64 outputs may be cross-built on the pinned
  macOS toolchain. Native/equivalent release evidence remains owned by the relay
  release contract and cannot be inferred from cross-compilation.
- iOS targets, TestFlight, App Store Connect, and App Review workflows are
  deferred with iOS. Their future checks are named for traceability but are not
  required checks on the macOS-only path and must never be reported as passed.
- Credential-free compile and static inspection are not signing, notarization,
  installation, Network Extension activation, VPN lifecycle, or publication
  evidence.
- The build host must not install or activate a system extension or VPN app,
  persist VPN preferences, call `startVPNTunnel`, or mutate routes or DNS.

## 2. Trust invariants

1. Untrusted source is any fork pull request, pull-request head, arbitrary
   branch, mutable tag, downloaded artifact without a verified digest, or
   rerun whose candidate identity differs from its original attempt.
2. Repository source becomes release input only as an exact commit reachable
   from the protected default branch and bound into an immutable candidate
   manifest. A tag is a label, never identity authority.
3. Workflow code that accepts a release candidate or can reach production
   credentials is loaded only from the protected default branch.
   `release-prepare.yml` is triggered only when the dedicated release-request
   GitHub App opens a typed issue; GitHub binds the `issues: opened` event to
   the default-branch workflow/ref/SHA. The issue, sender claims, requested
   commit, version, and request ID are untrusted inputs until independently
   resolved. Tag push, `repository_dispatch`, selectable-ref
   `workflow_dispatch`, `workflow_run` from candidate-controlled code, and
   relative reusable-workflow calls are not release entry points.
   `pull_request_target` is prohibited for building, executing, caching, or
   uploading pull-request code.
4. Workflow and job permissions default to `contents: read`; every other
   `GITHUB_TOKEN` permission is `none`. An additional read-only metadata
   permission may be granted without an environment only when its exact API
   call is inventoried. A write permission is granted only to its single call
   site after protected-environment approval. Repository Actions settings are
   a default, not a hard ceiling on same-repository workflow YAML, so no trust
   claim depends on them preventing a workflow from requesting write access.
   No production secret exists at repository or organization scope; protected
   environments restrict deployment refs to the protected default branch.
5. Pull-request jobs have no production environment and receive no certificate,
   private key, certificate password, App Store Connect issuer/key, provisioning
   profile secret, notarization credential, Sparkle private key, feed-origin
   credential, publication token, privileged runner, or route to a private
   production network. GitHub-hosted runners do have public Internet egress;
   that capability is treated as untrusted and never as release authority.
6. Every third-party action is pinned to a reviewed full commit SHA. A mutable
   tag, branch, range, or unreviewed action source fails before execution.
7. Pull-request caches and artifacts are untrusted accelerators. They are never
   release inputs; cache hits are revalidated against source and manifests.
8. Release jobs consume one candidate manifest and exact digests. Reruns may
   reuse that identity but may not resolve a new tag, branch head, dependency,
   cache namespace, or artifact under the old release attempt.
9. Production publication is serialized and feed-last. Cancellation or any
   failed/missing/unknown prerequisite leaves the candidate non-promotable.
10. Absence and read failure are distinct. A missing optional row is `deferred`
    or `not-applicable`; an unreadable or indeterminate required input is
    `unknown` and fails closed.

## 3. Workflow and job inventory

All workflow files use explicit top-level and job-level `permissions`, bounded
timeouts, `set -euo pipefail` (or an equivalent fail-fast shell contract),
immutable action pins, and concurrency groups. `persist-credentials: false` is
required on every checkout unless the single publication step documents its
write need. The Network column records both runner capability and authorized
use: a GitHub-hosted runner has public egress even where trusted steps authorize
no post-bootstrap network use.

### 3.0 Existing `ci.yml` seed and migration boundary

The repository already has one seed workflow. It remains active while the
required workflows below are implemented, but its current display names are not
the final branch-protection contract and its green result is not release
authorization.

Triggers: push to `main` and pull requests targeting `main`.

| Current job | Actor trust and input | Token / environment / secrets | Network | Outputs / retention | Approval / successor |
| --- | --- | --- | --- | --- | --- |
| `generated-project-credential-free` | Untrusted PR or protected-branch source; exact event SHA plus pinned legacy repository commit and checked-in project/tool configuration | Top-level `contents: read`; no environment; no secrets | GitHub-hosted macOS public egress exists; current trusted steps use GitHub checkout plus checksum-pinned Mise/tool inputs | Privacy-safe build logs and generated-project evidence; 14d | None; splits into `build/workspace-legacy` and `build/apple-credential-free` |
| `validate` | Untrusted PR or protected-branch source; exact event SHA only | `contents: read`; no environment; no secrets | Ubuntu hosted-runner public egress exists; current trusted steps use GitHub checkout only | YAML/spec/board diagnostics in the Actions job log; repository Actions-log retention is not declared in this seed and is therefore unknown/non-promotable | None; replaced by `policy/github-actions` and `policy/board-spec` |
| `relay-toolchain` | Untrusted PR or protected-branch source; exact event SHA, checked-in relay supply-chain/toolchain manifests, Go module, and negative fixtures | `contents: read`; no environment; no secrets | Ubuntu hosted-runner public egress exists; current trusted steps use GitHub checkout and the checksum-pinned Go origin named by the toolchain manifest | Build/test/audit result in the Actions job log; repository Actions-log retention is not declared in this seed and is therefore unknown/non-promotable | None; maps to `build/relay-four-target` and `security/supply-chain` |
| `relay-portable-runtime` | Untrusted PR or protected-branch source; exact event SHA, four declared target/runner rows, checked-in relay manifests, and checksum-pinned host-tool inputs | `contents: read`; no environment; no secrets | GitHub-hosted macOS/Ubuntu public egress exists; current trusted steps use GitHub checkout and checksum-pinned Go/Syft origins named by the toolchain manifest | Four gated executables, SBOMs, manifest/checksums, and privacy-safe runtime reports; 14d, `if-no-files-found: warn`, therefore non-promotable | None; maps to `build/relay-four-target` |

The seed currently uses Linux for two distinct purposes: generic repository
validation (`validate` on `ubuntu-latest`) and relay work (`relay-toolchain` plus
the Linux rows of `relay-portable-runtime`). This is observed implementation,
not an architectural requirement. Every successor check required by the macOS
working-client path must be runnable on the declared GitHub-hosted macOS image;
none may depend on Linux runner availability. Relay owners may retain separate
native-Linux jobs as additional relay release evidence, but those jobs are not
prerequisites of the working-client build. The seed is retired or narrowed only
after its successor checks are required and green for the same exact head SHA,
so migration cannot create an unprotected interval.

Seed artifacts are non-promotable legacy evidence. In particular,
`relay-portable-runtime` currently uploads executables for 14 days, uses
`if-no-files-found: warn`, and does not wrap every file in the versioned
provenance envelope required by §6. Those facts are recorded gaps, not accepted
release semantics: no seed artifact may enter `release-prepare.yml`, staging,
signing, or publication. `TASK-260715-36gq4m`, `TASK-260715-82zzad`, and
`TASK-260715-2wjvlx` must replace warning-on-missing upload, bind exact digests
and provenance, and apply the candidate retention class before a relay artifact
becomes promotable.

### 3.1 `ci-policy.yml` — repository policy

Triggers: `pull_request`, `merge_group`, and push to the protected default
branch. Manual dispatch may run diagnostics but cannot replace a required event
result.

| Job / blocking check | Actor trust and input | Token / environment / secrets | Network | Outputs / retention | Approval |
| --- | --- | --- | --- | --- | --- |
| `policy/github-actions` | Untrusted PR, merge-queue, or protected-branch exact event SHA from a clean checkout; checked-in workflows and CI policy | `contents: read`; no environment; no secrets | GitHub-hosted macOS public egress exists; trusted steps authorize only GitHub checkout/action download by immutable SHA | Sanitized policy report and action/permission/runner/environment/cache/artifact inventory; verification/90d | None |
| `policy/board-spec` | Untrusted PR, merge-queue, or protected-branch exact event SHA from a clean checkout; board files, resource declarations, dependencies, and `.spec/` inputs | `contents: read`; no environment; no secrets | GitHub-hosted macOS public egress exists; no post-checkout use is authorized | Board/spec validation report and clean-tree assertion; verification/90d | None |
| `policy/version-release-metadata` | Untrusted PR, merge-queue, or protected-branch exact event SHA; proposed versions/tags/artifact names/release notes are evaluated without a release claim | `contents: read`; no environment; no secrets | GitHub-hosted macOS public egress exists; no post-checkout use is authorized | Version/tag/release-note report; verification/90d | None |
| `security/ci-threat-model` | Untrusted PR, merge-queue, or protected-branch exact event SHA; checked-in safe fixtures/dry-runs only, never real production credentials or publication | `contents: read`; no environment; no secrets | GitHub-hosted macOS public egress exists; trusted harness authorizes only isolated test endpoints it owns | Scenario-to-result report for fork/cache/artifact/tag/rerun/cancel/concurrency/credential threats; verification/90d | None |
| `security/sarif-publish` (trusted post-merge only; not a PR required check) | Protected-default-branch exact source SHA and exact digest of the accepted `security/supply-chain` report; never PR/fork code or artifact | `contents: read`, `security-events: write`; protected `security-reporting`; no production signing/publication secret | Egress-controlled release runner; only the GitHub code-scanning upload endpoint is authorized | SARIF upload receipt bound to source/report digests; verification/90d | Security environment approval |

`policy/github-actions` is the production policy-enforcement call site for
permissions, action pins, runner labels, environments, caches, artifacts,
timeouts, shell behavior, and concurrency. `policy/board-spec` must run
`task-board validate --json`, validate resource references and dependency
cycles, check spec links/format, and prove the checkout remains clean. Its
production wrapper must parse the JSON and exit nonzero unless `valid` is
exactly `true` and both `errors` and `warnings` are readable arrays allowed by
the checked-in policy. The raw `task-board validate` process exit is not
authoritative because revision `b3422b05226253a17676b9b84c764071fe3dbe74` was
observed to report `[PARENT_STATUS_MISMATCH]` and one issue while exiting 0.
Malformed/unreadable JSON, a missing field, any validation error, or any
unallowlisted warning is `unknown`/failure. `TASK-260715-2hef52` owns this
wrapper and an invalid-status negative fixture that invokes the same production
entry point and asserts nonzero; a direct CLI-only fixture is insufficient.

### 3.2 `ci-build-test.yml` — credential-free build and test

Triggers: `pull_request`, `merge_group`, and push to the protected default
branch. Every blocking row below runs on a declared GitHub-hosted macOS image
with pinned Xcode, Mise/Tuist, Swift, Go, and dependency inputs, including the
four-target relay cross-build. Relay owners may add separately named native
Linux evidence jobs, but branch protection for the macOS working-client path
does not require them. No self-hosted or credentialed runner is permitted.

| Job / blocking check | Actor trust and input | Token / environment / secrets | Network | Outputs / retention | Approval |
| --- | --- | --- | --- | --- | --- |
| `build/workspace-legacy` | Untrusted PR, merge-queue, or protected-branch exact event SHA from a clean checkout; generated-workspace inputs plus pinned legacy repository commit | `contents: read`; no environment; no secrets | GitHub-hosted macOS public egress exists; trusted bootstrap uses only checksum-pinned Mise/Tuist and legacy-source origins | Generator diff, scheme/config inventory, and preserved SwiftPM legacy results; verification/90d | None |
| `test/core-protocol` | Untrusted PR, merge-queue, or protected-branch exact event SHA; checked-in Swift/Go sources, schemas, vectors, and deterministic seeds | `contents: read`; no environment; no secrets | GitHub-hosted macOS public egress exists; no use is authorized after checksum-pinned bootstrap | Swift/Go test inventories, machine results, deterministic seeds; verification/90d | None |
| `build/apple-credential-free` | Untrusted PR, merge-queue, or protected-branch exact event SHA; generated macOS-only workspace plus pinned project/tool inputs | `contents: read`; no environment; no secrets; `CODE_SIGNING_ALLOWED=NO` | GitHub-hosted macOS public egress exists; no use is authorized after checksum-pinned bootstrap | Debug/Release build logs, static plist/entitlement/embed/link reports; verification/90d | None |
| `build/relay-four-target` | Untrusted PR, merge-queue, or protected-branch exact event SHA; pinned relay source/toolchain/target manifests and four declared target rows | `contents: read`; no environment; no secrets | GitHub-hosted macOS public egress exists; no use is authorized after checksum-pinned bootstrap | Four uniquely named candidates, hashes, identities, protocol smoke metadata; candidate/180d | None |
| `security/supply-chain` | Untrusted PR, merge-queue, or protected-branch exact event SHA; source, dependency locks, built candidates, and checked-in security/license policies | `contents: read`; no environment or production secret; no SARIF publication permission | GitHub-hosted macOS public egress exists; trusted scanner authorizes only its allowlisted pinned advisory source; outage is not a pass | Redacted secret/dependency/license/SBOM/notice reports and SARIF as untrusted verification artifacts; verification/90d | None |

The active Apple job builds only the approved macOS host/provider, package,
harness, and relay schemes. Deferred iOS target definitions are not generated or
built in macOS-only mode. A future resumed iOS credential-free simulator check
must use the same trust boundary but is not a macOS required check.

### 3.3 Authenticated release request and immutable candidate preparation

`release-prepare.yml` triggers only on `issues: types: [opened]`. GitHub binds
that event to the last protected-default-branch commit/ref and requires the
workflow file on the default branch. There is no tag/push trigger,
`repository_dispatch`, selectable-ref `workflow_dispatch`, or upstream
workflow whose code or output becomes authority. The request issue uses one
strict machine-readable template containing a unique request ID, intended
semantic version, and candidate commit. Its title, body, issue number, sender,
and every requested value are untrusted data.

The external request client uses a short-lived, repository-scoped GitHub App
installation token with exactly `Issues: write`; it creates the request through
the GitHub issue endpoint. The App has no Contents, Actions, Workflows,
Administration, Environments, Secrets, Checks, Deployments, or publication
permission and is not a protected-branch or protected-tag ruleset bypass actor.
The token is held outside repository Actions, is never copied into the issue or
exposed to the workflow, calls only the issue-creation endpoint, and records the
issue/audit receipt. Compromise can create, edit, close, reopen, label, or spam
issues and comments allowed by that repository permission, including replayed
or altered release requests; it cannot create/update/delete Git refs, GitHub
Releases, or release assets, make an unprotected commit eligible, approve an
environment, obtain production secrets, sign, or publish. Release owns
initiation; recorded engineering/security/release approvals remain separate and
mandatory at `release/review-gate`.

The first job requires the expected repository, `issues/opened` event and issue
template version, GitHub App installation/sender, unique issue and request IDs,
`github.ref` equal to the protected default branch, and `github.workflow_sha`
equal to the protected default-branch workflow revision whose file and policy
SHA-256 digests are checked in. It parses only the event payload captured for
that run, binds its digest, and never refetches a mutable issue body as
authority. It then resolves the requested commit independently and requires it
to be an exact commit reachable from the protected default branch.
`release/revalidate` runs all nine checks fresh for that exact candidate.
The intended `v*` tag must be absent and unreserved; it is created atomically at
the accepted candidate commit only by the later protected publication job.
Missing, replayed, ambiguous, moved, or inconsistent metadata is `unknown` and
stops before candidate acceptance.

Every credential-capable reusable workflow is called as
`owner/repository/.github/workflows/<file>.yml@<full-reviewed-commit-SHA>` and
that SHA plus file digest appears in the immutable candidate. Relative local
workflow calls and tag/branch refs are prohibited for release authority because
they resolve from mutable or caller-selected code.

| Job / blocking check | Actor trust and input | Token / environment / secrets | Network | Outputs / retention | Approval |
| --- | --- | --- | --- | --- | --- |
| `release/candidate-identity` | Default-branch `issues/opened` event; independently validate App sender, issue/template/request identity, immutable event-payload digest, and untrusted candidate SHA/version; require exact default-branch-reachable commit, absent intended tag, trusted workflow SHA, and policy digest | `contents: read`; no production environment; no secrets; external `Issues: write` request credential is unavailable to Actions | GitHub-hosted macOS public egress exists; only GitHub repository/ref/issue metadata reads are authorized | Immutable candidate manifest, issue/request identity, event digest, intended tag/version, commit ancestry, and workflow-provenance evidence; release-record/7y | Release-owner initiation; not release approval |
| `release/revalidate` | Exact immutable candidate manifest and the nine checked-in required-check definitions at the accepted policy revision | `contents: read`; no production environment; no secrets | GitHub-hosted macOS public egress exists; only immutable GitHub action/checkouts and checksum-pinned Mise, Tuist, Go, Syft, dependency, scanner, and advisory origins declared by the candidate are authorized; no production endpoint | Fresh result and digest for every active required check; release-record/7y | None |
| `release/review-gate` | Exact candidate manifest plus complete fresh active evidence index and recorded approval identities | `contents: read`; no production environment; no secrets | GitHub-hosted macOS public egress exists; no network use is authorized after checkout/evidence retrieval | Machine verdict: promotable/non-promotable/unknown; release-record/7y | Recorded engineering/security/release approvals; human ratification remains `TASK-260717-2d308k` before publication |

The candidate manifest records request identity, source commit, clean-state assertion, source and
dependency locks, toolchain/SDK/runner images, protocol and relay manifests,
marketing/build versions, intended absent tag, expected artifact names, the
trusted caller workflow SHA/policy digest, every reusable-workflow SHA/file
digest, and every evidence digest. It is immutable after
`release/review-gate` starts.

### 3.4 `release-relay.yml` — relay staging

Trigger: reusable workflow call only from the exact full-SHA-pinned trusted
release workflow recorded by an accepted `release-prepare.yml` candidate.
Direct PR, branch, tag, relative local, mutable-ref, or arbitrary workflow calls
are rejected before protected-environment access.

| Job / blocking check | Actor trust and input | Token / environment / secrets | Network | Outputs / retention | Approval |
| --- | --- | --- | --- | --- | --- |
| `release/relay-rebuild` | Exact accepted candidate source, toolchain, dependency, protocol, and four-target manifests | `contents: read`; no production environment; no secret | GitHub-hosted macOS public egress exists; only checksum-pinned tool/bootstrap origins are authorized | Two isolated four-target trees and byte/identity comparison; candidate/180d | None |
| `release/relay-compliance` | Exact rebuilt bytes and accepted security/license/SBOM/notice policies | `contents: read`; no production environment; no secret | GitHub-hosted macOS public egress exists; only the pinned allowlisted advisory source is authorized | Manifest, checksums, SBOM, notices, scan, and provenance; release-record/7y | Relay/security policy owners through accepted contracts |
| `release/relay-stage` | Exact compliance-approved artifact and manifest digests from the immutable candidate | `contents: read`; protected `relay-staging`; narrowly scoped staging credential if a remote store is used | Egress-controlled release runner; only the named staging endpoint is reachable | Immutable digest-addressed staging receipt; release-record/7y | Environment approval by release owner |

Staging is not public promotion. A Linux runner is not required by this
workflow; any native Linux equivalence claim must cite separately accepted
evidence owned by `TASK-260715-pa6evr` and `TASK-260715-36gq4m`.

### 3.5 `release-macos.yml` — protected macOS release

Trigger: reusable workflow call only from the exact full-SHA-pinned trusted
release orchestrator recorded for one immutable candidate. Relative local and
mutable-ref calls are rejected before protected-environment access. Production concurrency group is
`relux-production-release` with `cancel-in-progress: false`.

| Job / blocking check | Actor trust and input | Token / environment / secrets | Network | Outputs / retention | Approval |
| --- | --- | --- | --- | --- | --- |
| `release/macos-build-inspect` | Exact immutable candidate and relay staging receipt; fresh build from accepted source, never PR artifacts/caches | `contents: read`; no production environment; no secrets | GitHub-hosted macOS public egress exists; only checksum-pinned dependency/bootstrap origins are authorized | Unsigned archive inputs and inspection report; candidate/180d | None |
| `release/macos-sign-notarize` | Exact inspected app/archive bytes and public signing-policy identifiers | `contents: read`; protected `macos-signing`; Developer ID identity/profile/password and named notary credential only | Egress-controlled macOS release runner; only required Apple timestamp/notarization endpoints are reachable | Signed app/DMG, public identity/team/profile metadata, notarization/stapling/Gatekeeper evidence; release-record/7y | macOS signing environment approver |
| `release/macos-sparkle-sign` | Final immutable notarized/stapled DMG and exact expected digest/version/channel metadata | `contents: read`; protected `sparkle-signing`; Sparkle EdDSA private key only | Egress-controlled macOS release runner with enforced no-egress boundary | Payload signature and proposed signed appcast; release-record/7y | Two-custodian ceremony policy plus environment approval |
| `release/macos-publish-assets` | Exact verified DMG, checksum/signature receipts, intended absent tag, and candidate metadata | `contents: write`; protected `github-release`; publication token only | Egress-controlled release runner; only exact GitHub release/asset/tag endpoints are reachable | Protected tag created atomically at the candidate commit, versioned immutable asset, checksum, stable manual-download alias receipt; release-record/7y | Release environment approval |
| `release/macos-publish-feed` | Exact published-asset receipt plus remote digest/header/privacy probe policy | `contents: read`; protected `update-feed`; minimum external feed-origin write credential only | Egress-controlled release runner; only the exact update origin is reachable | Atomic feed-last receipt, signed feed, and remote verification; release-record/7y | Release environment approval after asset verification |
| `release/finalize-evidence` | Exact candidate, approval, staging, signing, notarization, asset, feed, and remote-verification receipts/digests | `contents: read`; no production environment; no secrets; no secret-bearing output | Egress-controlled release runner; only required distribution endpoints are reachable read-only for final verification | Final evidence index and disposition; release-record/7y | Release owner |

Credential scopes are not shared across jobs. A compromised low-privilege
publication credential cannot sign, notarize, alter candidate identity, or erase
the retained evidence root. Temporary credentials are preferred; every secret
is masked and revoked/rotated after suspected exposure.

### 3.6 Deferred workflow registry

`release-ios.yml` (archive, entitlement/provisioning inspection, TestFlight,
App Store Connect evidence) and App Review submission are defined only as
future ownership under `TASK-260715-3661ps`, `TASK-260715-8g5fpa`,
`TASK-260715-dsvvnu`, and `TASK-260715-sfkrzq`. They have no active trigger,
environment, secret, or required-check status until ADR-024/027 and Gate A0/P0
are explicitly resumed. `deferred` is the only truthful current result.

## 4. Required-check and branch-protection policy

The protected default branch and merge queue require the following exact check
names. A skipped, cancelled, timed-out, neutral, stale, missing, or unknown
result is non-success and blocks merge. Administrators and bots do not bypass
the rule; emergency changes use the separately audited exception process and
must restore all checks before release eligibility.

1. `policy/github-actions`
2. `policy/board-spec`
3. `policy/version-release-metadata`
4. `build/workspace-legacy`
5. `test/core-protocol`
6. `build/apple-credential-free`
7. `build/relay-four-target`
8. `security/supply-chain`
9. `security/ci-threat-model`

Checks are accepted only for the exact current pull-request head SHA. A base
update, force-push, merge-queue synthetic commit, workflow-policy change, or
dependency-lock change invalidates stale results. Branch protection must reject
ambiguous duplicate check names from different workflows/apps. Release
promotion additionally requires the three `release-prepare` checks and the
applicable protected release receipts; PR checks alone never authorize release.

## 5. Epic requirement traceability

Each requirement has one primary blocking check. Supporting checks may provide
evidence but cannot substitute for the named owner.

| Epic/story CI requirement | Primary blocking check | Downstream owner | Platform/review owner |
| --- | --- | --- | --- |
| Explicit least permissions, immutable actions, runner/environment/cache/artifact policy | `policy/github-actions` | `TASK-260715-2wjvlx` | Security/review |
| Board structure, resources, dependencies, and spec integrity | `policy/board-spec` | `TASK-260715-2hef52` | Review |
| Generated-workspace drift plus preserved SwiftPM/legacy lane | `build/workspace-legacy` | `TASK-260715-3mk4hs` | macOS |
| Shared Core and protocol conformance | `test/core-protocol` | `TASK-260715-1m3edc` | macOS/relay |
| Credential-free host/provider compile and static entitlement/embed inspection | `build/apple-credential-free` | `TASK-260715-1uxx3i` | macOS; iOS row deferred |
| Four declared relay outputs, identity, checksums, protocol smoke | `build/relay-four-target` | `TASK-260715-36gq4m` | Relay |
| Secret, dependency, vulnerability, license, SBOM, and notice policy | `security/supply-chain` | `TASK-260715-38atsq` | Security/relay |
| Semantic version, tag, artifact names, and release notes | `policy/version-release-metadata` | `TASK-260715-2759wy` | Release |
| Immutable candidate and fresh revalidation | `release/candidate-identity` | `TASK-260715-2ybl7y` | Release/review |
| Trusted default-branch release entry point and immutable reusable-workflow provenance | `release/candidate-identity` | `TASK-260715-2ybl7y`, with policy enforcement by `TASK-260715-2wjvlx` | Security/release/review |
| Protected, serialized, idempotent promotion | `release/review-gate` | `TASK-260715-2ybl7y` | Release/security |
| Artifact metadata, digests, provenance, access, retention, deletion | `release/finalize-evidence` | `TASK-260715-82zzad` | Release/review |
| Adversarial fork/cache/artifact/tag/rerun/cancel/concurrency verification | `security/ci-threat-model` | `TASK-260715-vg2of8`; supporting policy and release dry-run evidence is mandatory input | Security/review |
| Relay release input and reproducibility authority | `release/relay-compliance` | `TASK-260715-pa6evr` | Relay/security |
| macOS signing/notarization/update identity and publication | `release/finalize-evidence` | `TASK-260715-1tzaed`, `TASK-260715-3gkwn0`; signing, Sparkle, asset, and feed receipts are mandatory inputs | macOS/release |
| Cross-platform go/no-go and separation of duties | `release/review-gate` | `TASK-260715-29r0k8` | Release/security/review |
| iOS archive/TestFlight/App Store pipeline | `release/ios-distribution` (inactive and deferred; not a macOS required check) | `TASK-260715-3661ps` and downstream iOS tasks | iOS/App Review |
| Human ratification of governance contracts | `release/review-gate` cannot pass publication without its evidence | `TASK-260717-2d308k` | Security/release/platform |

The active story decomposition is complete and atomic: contract, workflow
hardening, board/spec, workspace/legacy, Core/protocol, Apple credential-free,
relay, security/compliance, versioning, release orchestration, evidence, and
adversarial verification each have one clear owner. No new board element or
research task is justified by this contract. `TASK-260717-1s2eiz`, an
under-specified bootstrap duplicate, was closed as obsolete after confirming
that `.github/workflows/ci.yml` already supplies the seed and that all remaining
requirements map to the atomic owners above; its board note records the gap and
out-of-scope audit.

## 6. Artifact, provenance, retention, and network policy

### 6.1 Required provenance envelope

Every uploaded result contains a versioned manifest with: workflow/run/attempt,
event and actor trust class, exact source and protected-base commits, dirty-state
assertion, dependency lock digests, action SHAs, runner image, Xcode/SDK/Swift,
Mise/Tuist, Go and scanner versions, relay/protocol manifests and versions,
marketing/build versions, command inventory and exit status, artifact size and
SHA-256, signing public identity/team/profile identifier and expiry where
applicable, approval/environment receipts, and a redaction declaration. Private
material, secret values, raw profiles, user-home paths, traffic, destinations,
DNS names, cookies, and tokens are forbidden.

Artifacts are uploaded under attempt-unique, candidate-digest-addressed names.
Every downstream download verifies the expected manifest digest and each file
digest before use. GitHub artifact IDs or filenames alone are insufficient.
Release jobs rebuild from the immutable candidate or consume only protected
staging receipts; they never promote artifacts produced by untrusted PR code.

### 6.2 Retention classes

| Class | Content | Retention | Access/deletion |
| --- | --- | --- | --- |
| `diagnostic` | Redacted failed-step logs with no reusable binary | 14 days | Repository readers; automatic deletion |
| `verification` | PR/test/SARIF/policy reports | 90 days | Repository readers/security as scoped; automatic deletion |
| `candidate` | Unsigned/rebuilt candidate bytes and intermediate manifests | 180 days or candidate rejection + 30 days, whichever is later | Release/security; digest-indexed deletion audit |
| `release-record` | Published hashes, provenance, approvals, public signing/notary/feed receipts, SBOM/notices | 7 years | Append-only release/security evidence store; deletion requires recorded policy authority |
| `incident-hold` | Minimum redacted subset named by an incident | Until explicit legal/security release | Restricted; hold and deletion events audited |

Retention clocks and legal-hold applicability are policy-fill decisions for
later owner ratification; they do not authorize storing secrets or personal
traffic data.

### 6.3 Network and cache rules

- Standard GitHub-hosted runners have public Internet egress. For untrusted PR
  jobs this is an explicit capability, not an enforceable deny boundary; those
  jobs therefore receive no secret, write token, protected environment,
  privileged runner, private-production route, or promotable output namespace.
- Trusted steps authorize only exact GitHub endpoints, checksum-pinned
  package/tool origins, and advisory databases. Credential-bearing release jobs
  use an enforceable job-specific egress boundary or fail before secret access;
  only the owning job can reach Apple notarization, GitHub publication, relay
  staging, or the Relux update origin.
- Redirects, new hosts, mutable bootstrap responses, proxy injection, TLS
  failure, or inability to prove the protected job's egress boundary fail
  closed. Network inventories are retained in sanitized metadata.
- Fork PRs may restore only read-only caches keyed by trust class, OS image,
  exact tool/dependency/source hashes, and cache schema. They never save to a
  namespace restored by trusted/release jobs.
- Cache contents are never authoritative. Checksums, manifests, generated drift,
  linkage, and artifact inspection run on every hit. Poisoned or unreadable
  caches are discarded and the job rebuilds; inability to rebuild is failure.

## 7. Threat and failure-path contract

| Scenario | Required prevention/detection | Fail-closed result and recovery owner |
| --- | --- | --- |
| Forked code | No environment, secret, write token, self-hosted runner, privileged reusable workflow, or trusted cache/artifact namespace | PR remains failing; `TASK-260715-2wjvlx` fixes policy, `TASK-260715-vg2of8` proves it |
| Mutable action | Full-SHA policy rejects tag/branch/range before action execution | `policy/github-actions` fails; security reviews replacement SHA |
| Cache poisoning | Trust-separated keys; content verification after restore; release ignores PR caches | Discard/rebuild; verification failure blocks the owning build check |
| Artifact substitution | Candidate manifest and per-file digests verified at each transfer; untrusted artifacts never promote | Consumer fails before processing; evidence owner records attempted digest mismatch |
| Tag/workflow spoofing or race | Release preparation has no tag/push, `repository_dispatch`, or selectable-ref trigger; default-branch `issues/opened` code independently resolves App sender, issue/template/request identity, event digest, candidate ancestry, workflow/policy digests, and an absent intended tag; protected publication creates the tag atomically at the accepted commit | Unknown sender, replay, mutable/refetched issue authority, existing/moved/reserved tag, non-default workflow provenance, candidate-controlled workflow code, or digest mismatch makes `release/candidate-identity` unknown/failing before environment access |
| Rerun | Original candidate manifest/digests and policy revision remain fixed; attempt number is new | Changed identity creates a new candidate, not a rerun; old attempt stays non-promotable |
| Cancellation/timeout/runner loss | Bounded jobs, `always()` evidence finalizer that cannot override failure, no feed publication before all receipts | Cancelled/unknown, never success; revoke temporary material and resume from last immutable receipt |
| Concurrent releases | One production concurrency group, no cancel-in-progress, monotonic version reservation | Later candidate waits; conflicting version is rejected, never overwritten |
| Compromised low-privilege credential | Job-specific endpoint/scope; the request App has only `Issues: write`, so it can create/edit/close/reopen/label/spam request issues and comments but cannot mutate Contents, refs, Releases/assets, Actions/workflows, environments, secrets, or evidence; candidate validation ignores refetched mutable issue text and staging/publication credentials cannot cross job boundaries | Stop affected request/job, revoke/rotate, reject duplicate/altered requests, mark every affected candidate non-promotable, and let security own incident disposition |
| Missing/expired credential | Preflight proves availability without printing material | Required credentialed job fails; it is never `skipped-as-pass` |
| Partial publication | Versioned assets first, remote digest/header checks, signed feed atomically last | Feed withheld; exact receipts determine safe resume or withdrawal |
| Scanner/advisory outage | Distinguish no findings from unavailable database/service | `unknown` blocks `security/supply-chain`; security owner decides only through audited exception |
| Evidence/log upload failure | Gate result and evidence persistence are both required | Owning check fails even when build/tests passed |

No workflow may convert failure into success with `continue-on-error`, blanket
retry, fallback credentials, alternate unsigned feed/download, stale evidence,
or a summary-only aggregator. Matrix aggregation reports every child result and
fails unless all required children succeeded.

## 8. Negative evidence obligations

This task ships documentation, not enforcement code. The referenced
`references/negative-evidence.md` was not present in the repository or installed
skill trees during authoring, so its contents are `unknown`, not inferred.
Downstream implementations still must add tests that narrow and prove each
production call site:

| Production call site | Minimum rejecting fixtures |
| --- | --- |
| `policy/github-actions` / `TASK-260715-2wjvlx` | write permission, protected environment on PR, mutable action, privileged runner, unsafe cache namespace, missing timeout, duplicate check name, any `push.tags` workflow trigger |
| `policy/board-spec` / `TASK-260715-2hef52` | production-wrapper fixture with invalid hierarchy/status that proves reported issues cannot exit 0; missing/malformed/unreadable validator JSON; missing resource; broken ID/link; dependency cycle; spec-format failure; tracked mutation |
| `build/workspace-legacy` / `TASK-260715-3mk4hs` | target/scheme removal, generator/identifier drift, dirty generation, legacy regression |
| `test/core-protocol` / `TASK-260715-1m3edc` | omitted suite/vector, malformed/oversized input regression, timeout, leak, retry-dependent flaky pass |
| `build/apple-credential-free` / `TASK-260715-1uxx3i` | identity lookup, iOS scheme in macOS-only mode, identifier/embed/entitlement/link/version drift, signing claim from unsigned output |
| `build/relay-four-target` / `TASK-260715-36gq4m` | missing/duplicate target, mutable fetch, target/identity/protocol/checksum mismatch, partial matrix |
| `security/supply-chain` / `TASK-260715-38atsq` | private key/token/password, prohibited license, vulnerable lock, missing SBOM component/notice, over-broad or expired suppression |
| `security/sarif-publish` / `TASK-260715-38atsq`, `TASK-260715-2wjvlx` | PR/fork invocation, unprotected source, missing environment approval, report/source digest mismatch, permission broader than `security-events: write`, non-GitHub upload endpoint |
| `policy/version-release-metadata` / `TASK-260715-2759wy` | malformed/nonmonotonic/duplicate tag or build, dirty source, missing release-note section, incompatible protocol |
| `release/candidate-identity` and `release/review-gate` / `TASK-260715-2ybl7y` | tag push or `repository_dispatch` whose candidate YAML requests `write-all`, an unauthorized runner, arbitrary network, cache, or artifact upload must produce no release-preparation run; wrong event/repository/sender/App installation; malformed issue template; refetched/edited issue substituted for the captured event; replayed issue/request ID; non-default/selectable-ref dispatch attempt; unprotected candidate SHA; existing/moved/reserved tag; missing/mismatched `github.workflow_sha` or policy digest; relative or candidate-ref reusable workflow; stale check SHA; missing approval/evidence; duplicate version; cancellation; mixed receipts. Each fixture must prove rejection before candidate acceptance or protected-environment access |
| Release-request App credential / `TASK-260715-2ybl7y` | With the real installation token permission manifest or an API-permission emulator, attempt Contents/ref create-update-delete, GitHub Release create-update-delete, release-asset upload-update-delete, Actions/workflow dispatch, environment/secret access, and issue create-edit-close-reopen/label operations. The first group must be denied while the issue-only group demonstrates the bounded compromise capability; token-permission drift fails `policy/github-actions` before release initiation |
| Artifact/evidence consumers / `TASK-260715-82zzad` | digest substitution, missing file, tamper, redaction failure, expired evidence, artifact-ID/name collision |
| `release/relay-stage` / `TASK-260715-2ybl7y`, `TASK-260715-pa6evr` | direct/unapproved invocation, wrong candidate or digest, substituted bytes, missing environment approval, compromised staging credential attempting sign/publish/delete, concurrent version collision |
| `release/macos-sign-notarize` / `TASK-260715-3gkwn0`, `TASK-260715-3sk5cd`, `TASK-260715-387eof` | missing/expired/wrong-scope credential, approval bypass, identity/profile/entitlement mismatch, notarization reject/timeout/unknown, post-notary byte mutation, concurrent candidate |
| `release/macos-sparkle-sign` / `TASK-260717-ziprhs` and macOS update pipeline owner | wrong candidate/DMG digest, missing two-custodian approval, key unavailable/compromised, signature verification failure, Developer ID and EdDSA rotation in one update |
| `release/macos-publish-assets` / `TASK-260715-1njthi` | approval bypass, wrong digest/version, duplicate or mutable asset, partial upload, compromised token attempting signing/feed/evidence deletion, concurrent publication |
| `release/macos-publish-feed` / macOS update pipeline and release owners | feed-before-assets, missing/failed remote digest/header/privacy probe, redirect or origin drift, partial/nonatomic feed write, wrong signature/channel/version, concurrent publication |

Tests must assert the real nonzero/blocked result and the exact production
validator or workflow job. Deleting a fixture or testing only an allow case is
not evidence that the rejecting bound exists.

## 9. Approval, disputes, and change control

The autonomous draft is reviewed by an independent reviewer agent before the
solution-architect handoff. Human security, release, and platform ratification
is intentionally consolidated in `TASK-260717-2d308k`; its pending status does
not block downstream implementation of this accepted draft, but publication
cannot pass `release/review-gate` without its recorded verdict.

No current trust decision is disputed. The exact retention durations,
environment names, endpoint allowlists, and whether the separately protected
trusted-branch SARIF publisher is enabled are policy-fill decisions because the
source specs require those controls but do not fix their exact values. They were
selected to produce a testable least-privilege contract after checking the
task's explicit non-scope: they do not reinterpret A0, require Linux CI for the prototype,
activate iOS, issue credentials, implement workflows, or make legal/App Review
decisions. Human ratification may narrow them; any broadening requires a written
threat-model delta, accountable security/release owner, negative fixture, and a
fresh review.

Any later dispute records: the exact row, current evidence, two or more viable
options, security and release trade-offs, recommendation, accountable owner,
and the decision deadline. Until resolved, the affected required check or
release gate remains failing/unknown; unrelated credential-free work continues.

Changes to workflow triggers, permissions, action pins, runner classes, cache or
artifact trust, release environments, credential scope, publication order,
retention, provenance schema, or required-check names require review of this
contract and `.spec/threat-model.md` in the same change.

## 10. External platform basis

The trusted-entry design follows GitHub's documented execution model: the
`issues` event uses the last default-branch commit/ref and requires its workflow
file on the default branch; creating an issue through the API needs only
fine-grained `Issues: write`; workflow/job YAML can adjust the repository's
default token permissions; GitHub-hosted runners have public Internet access;
and full commit SHAs are the safest reusable-workflow reference. See
[events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#issues),
[create issue API](https://docs.github.com/en/rest/issues/issues#create-an-issue),
[workflow permission calculation](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#how-permissions-are-calculated-for-a-workflow-job),
[GitHub-hosted runner networking](https://docs.github.com/en/enterprise-cloud@latest/actions/concepts/runners/private-networking#about-github-hosted-runners-networking),
and [reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows).
