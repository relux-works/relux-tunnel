# Relay release input and reproducibility contract

Task: `TASK-260715-pa6evr`; parent: `STORY-260715-19mjyn`.
Status: autonomous draft, subject to independent agent review. Human ratification
is separately owned by `TASK-260717-2d308k`; no human approval is asserted here.

## 1. Authority and scope

This document defines the M5 unsigned relay input contract. It consumes the
accepted M2 source, toolchain, asset, and supply-chain records without changing
their bytes. It does not implement builds, change protocol behavior, authorize
Apple signing or publication, install a relay remotely, or run a VPN.
Accepted board evidence is not evidence that a draft has landed on main.

Inspected source baseline: `b3422b05226253a17676b9b84c764071fe3dbe74`.
The worktree HEAD equalled freshly advertised/fetched origin main during this
analysis. The following sources control, in descending order: current explicit
task scope and `.spec/delivery.md` deferrals; accepted CI trust contract
`TASK-260715-whtdsf_ci-trust-and-quality-gate-contract.md`; accepted protocol
contract `TASK-260715-pa6evr_protocol-v1-developer-contract.md` (SHA-256
`deb63fe2864dcd7f571d92333d82a7a06bd72cbfe08792b052aa9d6ba4bc22e6`);
the pinned M2 records below; this M5 policy fill. A conflict is an owned release
failure, not permission to choose the more permissive source.

The attached CI contract is an accepted draft policy, not a claim that all its
jobs are implemented. Current local code inspection supports only the named
existing gates. No Linux execution or new two-build result is claimed by this
document task. Linux CI remains deferred for the working-client path; the
four-target release certification remains incomplete until its native rows run.

## 2. Immutable input authority

### 2.1 Accepted baseline pins

`relay/supply-chain-source-v1.json` is the baseline source/recipe authority;
`relay/toolchain-manifest-v1.json` controls tool archives and target parameters;
`relay/asset-bundle-source-v1.json` controls accepted executable bytes.
Do not replace these records with a branch tip, a tag, a local tool version
string, or a newly computed hash of an unapproved input.

| Input | Exact accepted pin or authority |
| --- | --- |
| Relay source revision | `58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096` |
| Repository / relay trees | `f652536c11d3e6e34a6be89a4be808e489c99cd3` / `addc5400556304d5f5005404ed77a66883f575b3` |
| Compiled source aggregate | SHA-256 `29b6caac4fcaf54436521f17b47319ce8b77971991c0dc284c30296e11d69842`; exact file list and individual hashes in `source.byteAffectingFiles` |
| Recipe revision | `4326036a26a515d5d349e669574323d4d1c7259c` |
| Recipe aggregate | SHA-256 `0c3f4306c744e33389bd825f5f16d37028c4fc8aa997641e19dd7b8e9f82811d`; `Makefile`, `scripts/relay_release.py`, `relay/toolchain-manifest-v1.json` only |
| Dependency lock | `relay/go.mod`, SHA-256 `bd56300ba5f8e2263128ac97c6852ea42770644808a14d54a04113f23200deb6`; standard library only; no `go.sum` required for this baseline |
| Relay version / source epoch | `0.1.0` / `1784656987` |
| Compiler, linker, standard library | official Go `go1.26.5`, internal linker; archive digests below; no external C compiler, SDK, sysroot, or container |
| SBOM generator | Syft `1.48.0`, revision `3e2bc6ed095f7ec1a415fb38cfe1c319e95dfed6`; archive digests below |
| Accepted portable archive | `TASK-260715-24icoz_portable-relay-assets.tar.gz`, SHA-256 `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e` |
| Four accepted executable size/hash tuples | `relay/asset-bundle-source-v1.json:assets`; all four are mandatory, with no substitution |
| Protocol | wire/schema version `1`; schema, generated binding and vector bytes are pinned by the candidate file inventory and accepted protocol contract |

| Build host | Go archive SHA-256 | Syft archive SHA-256 |
| --- | --- | --- |
| darwin/amd64 | `6231d8d3b8f5552ec6cbf6d685bdd5482e1e703214b120e89b3bf0d7bf1ef725` | `dc7b2135fa5591003596df4ddb3408f499b68174f5e7dc1c77a373b753463182` |
| darwin/arm64 | `efb87ff28af9a188d0536ef5d42e63dd52ba8263cd7344a993cc48dd11dedb6a` | `fef3e6d5df336a0a4c3e421e503119d1e221cf82a3ef5e426a791fcd81667e87` |
| linux/amd64 | `5c2c3b16caefa1d968a94c1daca04a7ca301a496d9b086e17ad77bb81393f053` | `6cef9a7f37220d9067eaf9cfaaa2fce986e9f320a8d42cbc36658c99af78ea04` |
| linux/arm64 | `fe4789e92b1f33358680864bbe8704289e7bb5fc207d80623c308935bd696d49` | `6865a3d97c4e28b4b38571c17a2bf512da4494ef1d37613c3122fce0d67e63b0` |

Archive names and immutable origin URLs must equal their host rows in the
toolchain manifest. Verify retained archive and installed-tree receipts, not
only `go version` or `syft version`. Provision separately; build offline.

The historical source predates the recipe. Reproduction uses two independently
clean source clones and overlays only the three pinned recipe files, verifies
the compiled-source inventory unchanged, then uses `--require-provenance`.
The overlaid tree is intentionally dirty; it must not be labelled a
`--require-clean` invocation. The historical command recorded in M2 provenance
is retained verbatim as historical evidence, not rewritten to disguise this
distinction. See `docs/relay-asset-release-runbook.md` for the existing procedure.

### 2.2 Candidate input-lock schema (normative M5 specification)

Owner `TASK-260715-3e7noa` materializes `relay-release-inputs-v1.json` before
building a release candidate. This schema is a developer specification, not an
implemented validator or a populated release lock. All objects are closed;
all fields below are required. SHA-256 values are lowercase 64 hex; Git
revisions are full 40 lowercase hex for this repository; sizes/epochs are
non-negative integers; required strings are nonempty. No `latest`, wildcard,
tag-only pin, null, unresolved placeholder, or unreadable input is admissible.

| Field | Type and invariant |
| --- | --- |
| `schemaVersion`, `contractSHA256` | constant `1`; exact reviewed bytes of this contract |
| `source` | object: repository URI, commit, tree, relayTree, aggregateSHA256, file inventory `{path, sha256, size}`; inventory derived from actual compiled/embed/generated inputs, not a hand-maintained subset |
| `recipe` | object: commit, aggregateSHA256, file inventory, ordered command/argument arrays; declared source overlay with exact old/new hashes |
| `dependencies` | object: locks `{path, sha256}`, modules `{path, version, contentSHA256, origin}`, submodules `{path, commit, tree, contentSHA256}`, vendored inputs `{path, revision, contentSHA256, origin}`, generation inputs `{path, sha256}`; explicit empty arrays only after successful enumeration |
| `tools` | array: name, version, executableSHA256, archiveSHA256, immutable origin, host; compiler/linker/stdlib, Syft, Git, Python, Make, shell, compression and inspection tools, scanners and schema validators actually invoked |
| `environment` | object: buildHostOS, buildHostArch, osBuild, runnerImage `{kind, identifier, digest}`, container `{kind, identifier, digest}`, allowlisted variables, CPU baselines, network policy, umask, filesystem/case behavior; `kind=none` requires literal `identifier=none,digest=none` and a reason, only for an unused image/container |
| `workflow` | object: trusted workflow commit/file SHA-256, action/reusable-workflow commits and file hashes, policy hashes, builder identity; source authority bound independently of untrusted candidate claims |
| `release` | object: relayVersion, sourceDateEpoch, protocolVersion=1, target rows from section 3, approved aggregate byte budget, normalizationRevision and schema hashes |
| `security` | object: policySHA256, scanner configuration hashes, advisory snapshots `{origin, sha256, generatedAt, fetchedAt, expiresAt}`, license policy hash; exception decisions are downstream evidence, not input-lock members |

The input-lock file's SHA-256, computed externally (no self-hash field), is the
candidate input identity. A trusted candidate manifest binds it before builds.
An actual output set is bound later by the staging index; neither overwrites
the input lock. Exceptions bind this input identity only after it is frozen;
the staging index pins their exact bytes. The input lock never hashes a record
that refers back to its own hash. Every input change creates a new candidate and invalidates
previous comparison, scan, and approval evidence.

Submodules/vendor code elsewhere in the Apple product are not automatically
relay dependencies. Derive relay coverage from pinned source, imports and
embedded resources; reject undeclared `require`, `replace`, workspace, cgo,
vendor or submodule inputs. Adding one requires reviewed lock/license/SBOM
updates. The product-wide notice owner separately covers HEV, its submodules,
lwIP and the selected SSH engine; they must not be falsely listed as linked
inside the relay.

The current M2 record explicitly has no container, but hosted runner labels
such as `ubuntu-24.04` are mutable. They are runtime fixture selectors, not
immutable image pins. Exact M5 runner/OS snapshot, auxiliary tool, scanner and
advisory digests are not present in the accepted baseline. They must be filled
and verified by `3e7noa`, `36gq4m`, `38atsq` and `nwcp1j`; a populated format
without independently verified content is insufficient. A runner provider that
cannot supply an immutable restorable image requires a pinned VM/image lane,
or a separately reviewed narrower reproducibility claim; never invent an image
digest or label a mutable runner hermetic. This blocks release certification,
not development of this accepted draft or the deferred-Linux working client.

## 3. Targets, identity and executable boundary

| Go target | Canonical triple | CPU baseline | File name | Runtime/format contract |
| --- | --- | --- | --- | --- |
| darwin/amd64 | x86_64-apple-darwin | GOAMD64=v1 | relux-relay-darwin-amd64 | Mach-O x86_64, macOS 12.0 minimum |
| darwin/arm64 | aarch64-apple-darwin | GOARM64=v8.0 | relux-relay-darwin-arm64 | Mach-O arm64, macOS 12.0 minimum |
| linux/amd64 | x86_64-unknown-linux | GOAMD64=v1 | relux-relay-linux-amd64 | static ELF64 x86_64, Ubuntu 24.04 native fixture |
| linux/arm64 | aarch64-unknown-linux | GOARM64=v8.0 | relux-relay-linux-arm64 | static ELF64 AArch64, Ubuntu 24.04 native fixture |

Darwin loads only `/usr/lib/libSystem.B.dylib` and
`/usr/lib/libresolv.9.dylib`; Go internal linker emits minos/sdk 12.0.
Linux has neither `PT_INTERP` nor `PT_DYNAMIC`; no older kernel floor is
claimed. No universal/fat binary, alternate libc variant or additional target.
Target ordering is the table order. OS labels are `darwin` and `linux`, arch
labels `amd64` and `arm64`; map probe x86_64 to amd64 and aarch64 to arm64,
with Darwin arm64 unchanged. Unknown combinations fail selection.

Only `--identity --protocol 1` and `--stdio --protocol 1` are supported.
Identity is one JSON object plus newline with exactly `schemaVersion=1`,
`relayProtocolVersion=1`, `relayVersion`, `sourceCommit`, `os`, `arch`,
`selfSha256`; self-hash covers the exact running executable. Source commit is
the compiled source pin, not the recipe commit. The unsigned build identity
does not contain a run ID, timestamp, absolute path or embedded self-hash.
Consumers compare all fields with the trusted manifest before stdio use.

The relay is an unprivileged sshd exec child, no daemon/root/public listener,
and stdout is protocol-only in stdio mode; diagnostics use bounded stderr.
No runtime executable fetch is authorized. Preserve the accepted protocol v1
handshake, feature and limit semantics; a version string is not compatibility
proof. `make relay-protocol-check` is the release compatibility gate; exact
asset identity/stdio/native tests are separately owned by `1c4l9v` and
`36gq4m`. Unsupported or mismatched identity/protocol cannot be waived into v1.

## 4. Reproducibility and normalization

Build with `-mod=readonly -trimpath -buildvcs=false -tags=netgo,osusergo` and
`-ldflags='-s -w -buildid= -linkmode=internal -X <module>/internal/buildinfo.Version=<relayVersion> -X <module>/internal/buildinfo.Commit=<sourceCommit>'`.
`<module>` is `github.com/relux-works/relux-tunnel/relay`. This describes the
existing recipe; do not execute template placeholders.

Required environment: `GOTOOLCHAIN=local`, `CGO_ENABLED=0`, `GOENV=off`,
`GOWORK=off`, `GOPROXY=off`, `GOSUMDB=off`, `GOVCS=off`, `LC_ALL=C`,
`LANG=C`, `TZ=UTC`, pinned `SOURCE_DATE_EPOCH`, exact GOOS/GOARCH and CPU
baseline. Go flags/experiments must not leak from the host. Use a PATH composed
only of verified tools, isolated HOME/TMPDIR/GOCACHE/GOMODCACHE/GOPATH,
no inherited credentials, and no-follow contained workspace paths.

| Allowed deterministic transformation | Rationale and required test |
| --- | --- |
| Compile-time trimpath, buildvcs=false, empty build ID, pinned version/commit | Remove host path/VCS/run entropy without editing an executable afterward. Build two independently cloned roots with different absolute paths, host locale/TZ and wall clocks, empty nonshared caches; require exact bytes and inspect embedded identity. Owner `3kepzm`. |
| SPDX `/documentNamespace` becomes `https://relux.works/spdx/relux-relay/<binary-name>/<binary-sha256>` | Removes Syft UUID while preserving a content-addressed identity. Existing `test_spdx_metadata_normalization_controls_time_uuid_and_json_order`; binary mutation must change namespace. |
| SPDX `/creationInfo/created` becomes source epoch formatted UTC `YYYY-MM-DDTHH:MM:SSZ` | Document-generation clock is not component content. Same test plus `test_spdx_normalization_rejects_invalid_missing_and_impossible_metadata`; raw wall-clock retained only in run evidence. |
| SPDX JSON object keys sorted, UTF-8, two-space indent, ensure_ascii=false, final LF | Canonical serialization only; no package, relationship, checksum, license or array deletion/reordering. Existing normalization and `test_generate_sbom_normalizes_dynamic_syft_fields_before_verification` tests. Other generated JSON uses its pinned serializer, never an arbitrary compare-time reformatter. |
| Staging file modes 0755 executables, 0644 metadata; directories 0755; umask 022 at creation | Host umask must not alter packaged permissions. Proposed M5 packer test varies umask and rejects modes that differ after prescribed construction; `3kepzm`/`28y0uc`. Existing comparator already rejects mode drift. |
| New M5 tar entries: relative UTF-8 POSIX names in bytewise order, no explicit directory entries, uid/gid=0, uname/gname empty, mtime=source epoch, USTAR, no extended attributes/PAX/link entries | Archive filesystem metadata is not relay content. `28y0uc` must permute source enumeration/mtime/uid and prove byte equality, then change content and require failure. Reject names not representable in USTAR; do not silently choose another format. |
| New M5 gzip header: mtime=0, no original filename/comment, compression level 9, OS byte 255 using pinned compressor/runtime | Removes clock/host-header entropy. Same owner must vary input path/clock and prove equality; change compression pin or payload and invalidate evidence. |

No post-build binary transformation is allowed: no codesign removal, Mach-O
load-command rewriting, strip-after-build, ELF section deletion, UUID patching,
or semantic-only executable comparison. Any Go-generated signing metadata
remains part of the compared bytes; no Apple signing is performed here.
Existing retained archive hashes are historical identities; never recompress
one under the new M5 convention and call it the same accepted archive.

`TASK-260715-3kepzm` must obtain two independent unsigned builds with the same
locked inputs, no hardlinks/shared writable build cache, distinct roots and
run IDs. Each build must independently verify inputs and generate its own
outputs. Compare all four binaries byte-for-byte, all deterministic release
metadata byte-for-byte, file sets and modes exactly; archive bytes must also
match when the new deterministic archive is produced. That archive contains
exactly the 11 files under `release/` in section 5.2, with their `release/`
prefixes; no other staged or attempt file is an archive member. The independent
build comparison covers these 11 files and the four protocol-test binaries.
The two copies of the frozen input lock must also match their trusted digest.
The complete staged object is individually hash-verified, not claimed to be
bit-for-bit reproducible: its scans, provenance, catalog linkage, evidence and
staging index can bind genuine attempt-specific records. Duplicate executable
copies in `bundle/` must equal the four reproduced release binaries. A hash table alone does
not establish build independence. Cross-host claims require additional host
rows; two runs on one host support only that declared scope.

The current `scripts/relay_release.py compare` covers 11 release files and four
protocol-test binaries (15/15). It normalizes nothing during comparison and
reports first differing offset/hashes and bounded JSON paths. The new staging
gate must additionally verify the exact 11-member archive above; do not claim
the current comparator checks future files. Raw SPDX, scan databases, run
timestamps and environment/approval receipts are retained separately as
attempt evidence; they may differ, are individually hashed, and are never
silently dropped from a claimed deterministic payload. Semantic diffs diagnose
failure, never convert it into success. Unexplained differences are blocking
and non-waivable.

## 5. Artifact schemas and exact layout

The following schemas are normative M5 specifications except where an existing
schema is explicitly named. Their implementing tasks must ship strict machine
schemas and production-path negative tests. Every path is relative and unique;
reject absolute/traversal paths, links, devices, duplicate JSON keys, unknown
fields, omitted fields, unreadable/truncated data, duplicate/missing targets,
invalid hashes and cross-record mismatch. A failed read is unknown/failure,
never an empty inventory or clean scan.

### 5.1 Manifest layers

Retain `relay/manifest-v1.schema.json` for the builder manifest:
`schemaVersion`, `relayProtocolVersion`, `relayVersion`, `sourceCommit`,
`toolchain{go,cgoEnabled,syft}`, four `artifacts{os,arch,goTarget,canonicalTarget,filename,size,sha256,sbom,sbomSha256}`.
Retain `relay/asset-manifest-v1.schema.json` for the bundle catalog:
`schemaVersion`, `relayProtocolVersion`, `buildProvenance`, `supplyChain`,
four `assets` with fileName/bundleLocation/byteSize/sha256/buildIdentity and
provenance references as that schema specifies. Cross-field equality and exact
target set require semantic validation beyond JSON Schema. No new fields may
be inserted into these v1 objects. M5 adds linkage in a separate staging index;
changing the catalog authority requires explicit schema/consumer migration.

### 5.2 Layout

`relay/<relayVersion>/<sourceCommit>/<inputLockSHA256>/` is a candidate namespace,
not a mutable latest alias. An attempt gets its own `attempts/<run-id>/` evidence
directory. Once assembled, the staging object is addressed by staging-index
SHA-256; an attempt may not overwrite another result for the same input lock.

| Relative location inside staged object | Exact content |
| --- | --- |
| `release/` | Existing 11-file tree: four canonical executables, four `<binary>.spdx.json`, `relux-relay-manifest-v1.json`, `relux-relay-SHA256SUMS`, `THIRD_PARTY_NOTICES/Go-BSD-3-Clause.txt` |
| `bundle/relay-assets-v1/` | Four exact canonical executables plus `relux-relay-assets-v1.json` only; the app consumes this catalog, not the builder manifest |
| `inputs/relay-release-inputs-v1.json` | Frozen candidate lock from section 2 |
| `compliance/` | `dependency-inventory-v1.json`, `PRODUCT_NOTICES.txt`, `notice-map-v1.json`, `scan-v1.json`, `exceptions-v1.json` |
| `provenance/source-build-provenance-v1.json` | Preserved baseline provenance for baseline bytes; newly generated subject-correct record for new bytes |
| `evidence/` | `reproducibility-v1.json`, `conformance-v1.json`; immutable attempt references and hashes, not raw secrets or traffic |
| `staging-index-v1.json` | Closed complete file inventory excluding itself; every entry has path, role, target or explicit `all`, size, SHA-256, mode, producer task/run, inputLockSHA256 |

Any additional retained raw SPDX/log/advisory file lives in the attempt store
and is linked by digest in evidence; it is not an unlisted staging member.
The index has `schemaVersion=1`, `inputLockSHA256`, `sourceCommit`,
`relayVersion`, `protocolVersion=1`, sorted `files`, and `evidenceRefs`.
`evidenceRefs` records immutable URI, digest, type and run ID. The trusted
staging receipt binds the index hash and optional deterministic archive hash
externally, avoiding hash cycles. Do not hash a file that contains its own
hash. Existing manifest linkage uses the established acyclic supply-chain
linkage digest; do not replace it with a self-referential manifest hash.

### 5.3 SBOM, notices, scan and exception records

| Record and owner | Required data and consumers |
| --- | --- |
| SBOM, `37rtzn` | SPDX JSON 2.3, one per exact executable; document identity/time normalization above; package/file IDs, names, versions/revisions, SHA-256, immutable download locations, supplier/origin evidence, declared/concluded SPDX license, file/component/dependency relationships, target and executable linkage. Scanner UNKNOWN/NOASSERTION is not approval. Reconcile compiled inputs and standard library independently of Syft output. Consumers `151xf0`, `nwcp1j`, `28y0uc`, `3c06k7`. |
| `notice-map-v1.json`, `151xf0` | schemaVersion=1, inputLockSHA256, components array of componentID, target coverage, source revision/hash, distribution class, SPDX expression, license-text path/hash, notice obligation, notice output path/hash, review evidence reference. Every shipped component maps to full required notices. Build-only tools remain in inventory with explicit non-shipping reason. Consumers compliance/staging and containing-product notice assembly. |
| `scan-v1.json`, `nwcp1j` with `38atsq` | schemaVersion=1, inputLockSHA256, subjects path/hash/target, scanner names/versions/archive hashes/config hashes, advisory snapshot hashes and times, startedAt/finishedAt, command/exitCode, expected/scanned coverage counts and lists, findings, decision and exception references. Findings: ID, component/file digest, target, category, severity source/score, fixed version if known, disposition, redacted evidence hash. Consumer `release/relay-compliance`, staging, audit. |
| `exceptions-v1.json`, security + release + affected legal/relay owner | schemaVersion=1, policySHA256, entries with exceptionID, exact finding/subject/input-lock/target scope, reason, options considered, risk and compensating control, remediation task/owner/due date, issuedAt/expiresAt, independent approver identities/roles/decision receipt hashes, status. Empty entries means no exceptions only after successful authoritative read. Consumers scanner and promotion gate revalidate scope/expiry/revocation on every attempt. |
| `reproducibility-v1.json`, `3kepzm` | schemaVersion=1, inputLockSHA256, two distinct run refs, verified input inventories, host/image identities, normalization revision, full expected/compared member lists, per-file sizes/modes/hashes/equality, command exits, final decision. Consumer staging/audit. |
| `conformance-v1.json`, `1c4l9v` | schemaVersion=1, inputLockSHA256, four target subjects, exact executable hashes, protocol schema/vector digests, native OS/arch evidence, identity/stdio/hostile-input/resource/exit results, commands/exits, each row passed/failed/deferred/unknown. Deferred/unknown is never passed. Consumer staging/audit. |

## 6. License and security policy fill

These are testable draft choices for ratification, not legal advice or a claim
of completed security scanning. Inherited baseline licenses are MIT for relay
source and BSD-3-Clause for linked Go standard library, with exact license-text
hashes in `supply-chain-source-v1.json`. Syft Apache-2.0 and recipe MIT are
build-only. The baseline approval flags attest the accepted inventory policy;
they do not identify new human ratifiers of this M5 contract.

Release refuses missing/unknown license evidence, an unapproved new SPDX
expression, absent required text/attribution, incompatible notice mapping or
unapproved distribution obligation. Do not infer that an entire license family
is approved from these fixed components. Legal/compliance owns a reviewed
component-level allowlist; new/copyleft/dual-license choices require an explicit
decision recorded with exact version and selected license before distribution.

Proposed vulnerability policy: block Critical and High (CVSS >=7.0 where a
score exists; use the highest credible advisory rating), known-exploited
findings at any score, confirmed embedded secrets, prohibited executable-fetch
paths, and binary/identity/linkage failures. Unknown severity or incomplete
scanner coverage blocks rather than becoming Low. Medium/Low findings require
an owned remediation disposition; they are recorded, not hidden. Apply the
policy to linked/shipped dependencies and to compromised build inputs that
could affect output. The accepted static runtime-policy audit remains required;
it is not a vulnerability scanner.

Advisory snapshot generatedAt must be at most 24 hours before scan start;
scan must be at most 24 hours old at staging/promotion, with no future-dated
times and a verified snapshot digest. Scanner/database/config pins belong to
the frozen input lock. Refresh creates new scan evidence and, if locked inputs
change, a new candidate; outage/parse error/nonzero tool exit is failed/unknown.
Do not fetch a mutable database during deterministic build comparison.

Exceptions are finding-specific, signed/identity-verifiable decision receipts,
maximum 30 days, never wildcard source/target ranges or self-approval. Security
and release approve; legal/compliance additionally approves license matters;
relay owner validates compatibility/resource impact. Expired/revoked/mismatched
exceptions fail. Secrets, altered hashes, provenance substitution, unknown
inputs, missing native certification, protocol mismatch and unexplained
reproducibility differences cannot be waived. Removing a secret and rotating
it where necessary is a new verified candidate, not a suppression.

## 7. Provenance, staging and retention

Use in-toto Statement v1 (`https://in-toto.io/Statement/v1`) with SLSA provenance
v1 predicate (`https://slsa.dev/provenance/v1`) and the existing build type
`https://relux.works/build-types/relay-portable-v1`. Subjects are exact four
executable names/SHA-256; resolvedDependencies binds source, recipe, toolchain,
locks and all materialized inputs; externalParameters binds target matrix,
version, epoch and command; runDetails binds builder identity, invocation and
byproduct hashes. M5 binds input-lock and workflow/image evidence as resolved
dependencies/byproducts under the implementing schema. Do not fabricate an
attested builder or claim a SLSA assurance level from JSON shape alone.

`28y0uc` produces the staging provenance; `82zzad` owns protected evidence
storage. The existing repository-generated M2 provenance is unsigned and
hash-verifiable historical evidence. A trusted M5 attestation must bind the
new exact subjects and authentic builder/workflow identity with verifiable
issuer/signature/trust policy; author-supplied matching digests alone are not
attestation. No keys are acquired or signatures produced by this task. Apple
release attestation/signing stays with its separate owners.

`release/relay-compliance` must pass before `release/relay-stage` consumes the
candidate. `relay-staging` is the protected environment from the accepted CI
contract; a release owner approves remote staging. The store is digest-addressed,
attempt-unique and immutable. Downloaders verify a trusted receipt/index digest,
then every member and exact file set before use. Reject PR-artifact promotion,
partial upload, cross-candidate mixing, retries overwriting a prior candidate,
unknown receipts and concurrent namespace collision. A staging credential has
no signing/publication/deletion authority. `1lmmri` verifies copied bundle bytes
before Apple archive signing; its verification must run after the copy.

Retain raw and normalized SPDX separately, both build input receipts and logs,
comparison/scan/native evidence, exact accepted bytes, manifests, notices,
provenance and approval receipts. Archive reproducibility covers only the
explicit `release/` payload, never the whole staged object or a recompressed
attempt store. Redact secrets, user-home paths, traffic,
destinations and DNS names; preserve commands with logical workspace paths,
exit codes and digests. Never retain credentials as reproduction material.

| CI retention class | Duration and clock | Owner/consumer |
| --- | --- | --- |
| diagnostic | 14 days from attempt completion | CI; sanitized failure diagnosis |
| verification | 90 days from attempt completion | CI/security; review |
| candidate | Later of creation +180 days or rejection +30 days; unrejected candidate uses creation +180 days | Release/security; reproduce/rollback preparation |
| release-record | 7 years from publication; exact relay assets and rebuild inputs included to support rollback | `82zzad`, release/security/compliance; audit/rollback |
| incident-hold | Until explicit legal/security release; overrides deletion clocks | Restricted incident owner; minimal redacted evidence |

These clock anchors fill the predecessor's explicitly pending clock choice.
Deletion produces an audited policy-authority receipt; published records are
append-only. If provider artifact retention cannot meet this duration, retain
in the protected evidence store rather than treating an expired CI URL as
evidence. Re-scanning old accepted bytes does not authorize rollback of a
revoked/vulnerable release; `1z8ac2` must apply current revocation policy.

## 8. Ownership, open ratification and implementation traceability

No new board element is needed: existing atomic tasks cover all requirements.
IDs below have prefix `TASK-260715-` unless fully written. Dependencies already
link contract -> inputs -> build -> reproducibility -> manifest -> downstream
assembly; notices/scanning and conformance join before staging and final audit.

| Requirement | Primary existing owner | Deliverable / downstream gate |
| --- | --- | --- |
| Inputs, locks, immutable environments (AC1) | 3e7noa, supported by 36gq4m and 2wjvlx | Materialized lock and immutable runner/tool receipts -> 2pwg4j |
| Four executable targets and identity (AC2) | 2pwg4j | Exact four bytes -> 3kepzm and 37rtzn |
| Normalization and two isolated builds (AC3) | 3kepzm | Complete equality evidence -> 14flqo |
| Manifest and checksums (AC4) | 14flqo | Strict two-layer linkage -> 1lmmri and 1c4l9v |
| SBOM (AC4) | 37rtzn | Four target inventories -> 151xf0/nwcp1j |
| Notices (AC4) | 151xf0 | Complete relay + containing-product obligations -> nwcp1j |
| Scan/policy/exception enforcement (AC4–5) | nwcp1j, supported by 38atsq | Exact-subject scan and decisions -> 28y0uc |
| Native/protocol certification | 1c4l9v, supported by 36gq4m/1m3edc | Four native evidence rows -> 28y0uc; Linux execution deferred now |
| Provenance/staging/archive/retention (AC4) | 28y0uc, supported by 82zzad | Immutable staging object -> 1lmmri/3c06k7 |
| Apple bundle consumption | 1lmmri | Copied-byte verification -> release pipeline; no signing here |
| Update/rollback/revocation | 1z8ac2 | Operations contract -> 3c06k7 |
| Independent completeness audit | 3c06k7 | Source-to-staging audit -> release go/no-go |
| Human policy ratification (AC5, explicitly decoupled) | TASK-260717-2d308k | Security, release, relay/platform and legal/compliance receipts -> release/review-gate |

The owner roles are accountable functions; named human identities must be
recorded by the ratification task. No owner receipt currently exists for this
new contract. This does not block downstream implementation after agent draft
acceptance; it does block publication. Concrete choices for that existing task:

| Pending choice | Draft recommendation | Alternative and trade-off |
| --- | --- | --- |
| Vulnerability threshold | Block High/Critical and known-exploited at any severity | Block Medium too: smaller exposure, more release disruption; any weaker threshold needs explicit threat-model review |
| Advisory/scan freshness | 24 hours | 12 hours for reduced stale exposure at higher rescan cost |
| Exception duration | At most 30 days, scoped approvals | No vulnerability exceptions at all: simpler gate, possible release delays |
| License approval | Exact component/version allowlist with full notice evidence | Broader license-expression allowlist reduces review work but needs legal-approved obligation rules; not implicitly enabled |
| Retention anchors and exact bytes | Section 7 clocks, preserve release bytes/rebuild material 7 years | Longer retention or tighter restricted access by compliance decision; reducing the inherited durations needs CI-contract amendment |
| Immutable runner source | Restorable verified VM/image with exact auxiliary tool pins | Narrower observed-host reproducibility claim; does not satisfy an immutable-environment release claim without contract amendment |

Policy-fill justification: `.spec/delivery.md`, `.spec/validation.md`,
`.spec/relay-protocol.md`, the accepted CI contract and existing task scopes
require these controls but leave thresholds/clock anchors/exception duration
and final runner materialization open. The choices above close those exact
gaps. Scope checks exclude protocol changes, Apple signing, remote installation,
VPN execution and Linux working-client prerequisites. No speculative research
task, duplicate story, diagram or new product capability is introduced.

## 9. Validation contract and current evidence boundary

This document's AC verification is source-pin reconciliation, schema/consumer
review, scoped existing normalization/comparison tests and independent agent
review. It is not execution of downstream release builds or policy gates.

Existing production sites: `scripts/relay_release.py` toolchain verification,
`generate_sbom` -> `normalize_spdx_metadata`, `compare_release`;
`scripts/relay_asset_manifest.py` bundle generation/check;
`scripts/relay_supply_chain.py` audit. Downstream new input/scan/staging gates
must be exercised through their real CLI/job entry, not helper-only mocks.

Required negative evidence: omitted/duplicated fourth target, altered source or
archive digest, forged receipt, mutable runner tag, missing/unknown scanner DB,
expired scan and exception, substituted manifest, symlink/traversal member,
changed notice/component relationship, differing binary byte or file mode,
missing owner approval at publication, and bypass through retry/rollback.
Accept each actual limit and reject just beyond it (7.0, 24 hours, 30 days as
applicable); narrow a gate to one target/severity/entry point and require a
named fixture to fail. Report coverage against the independent four-target
spec and complete source-derived inventory. New archive normalization needs
the metamorphic tests in section 4 before use. No such new gate is shipped by
this prose change; its downstream owner must provide those tests.

The task outcome records exact commands, exit codes, reviewed artifact hashes,
review verdict and residual gaps. A `to-review` handoff is readiness for review,
not human ratification, landed code, or release certification.
