# TASK-260717-ziprhs Sparkle EdDSA key evidence

Date: 2026-08-30
Task: `TASK-260717-ziprhs`
State: evidence collected; Stop-The-Line provenance mismatch requires an owner decision

## Context

This task was asked to confirm the Sparkle Ed25519 keypair attributed to Ceremony
C1, record only non-secret public evidence and the custody store name, document
rotation and revocation, and scan the repository, authoritative board resources,
run logs, and shell history for private material. It does not pin
`SUPublicEDKey`, bind a CI secret, sign an appcast, publish an update, or prove a
working self-update path. Those downstream operations remain owned by
`TASK-260728-3bj9bk`.

The Story worktree was verified at
`b3422b05226253a17676b9b84c764071fe3dbe74`, exactly equal to fetched
`origin/main` before this evidence was trusted.

## Public evidence

| Field | Recorded value | Evidence |
| --- | --- | --- |
| Keychain item | Present as Sparkle account `ed25519` | Read-only generic-password metadata query; secret value was not requested |
| Public key (`SUPublicEDKey` value) | `tx8SLAmqME/ldUthxRV5PFQiUt1MX65blT29cA8My1U=` | Public comment metadata written by Sparkle's vendor tool |
| Public-key size | 32 decoded bytes | Strict Base64 decode |
| Fingerprint | `SHA256:Hp65O0qmEfLr+WjuZ9+k6Z9Lk8p6fEX3bK/EtHvza1Q` | SHA-256 of the decoded 32-byte public key; Base64 without padding |
| Fingerprint (hex) | `1e9eb93b4aa611f2ebf968ee67dfa4e99f4b93ca7a7c45f76cafc4b47bf36b54` | Same digest in hexadecimal |
| Pinned vendor release | Sparkle `2.9.4`, tag commit `b6496a74a087257ef5e6da1c5b29a447a60f5bd7` | Official tag and release API |
| Vendor archive | `Sparkle-2.9.4.tar.xz`, SHA-256 `ce89daf967db1e1893ed3ebd67575ed82d3902563e3191ca92aaec9164fbdef9` | Downloaded digest equals the digest published by the official GitHub release API |
| Keychain item creation date | `2026-07-05T02:04:52Z` | Read-only `cdat` metadata |
| Approved custody store name | login Keychain | C1 outcome and current Keychain item metadata; no filesystem path recorded |

The `generate_keys` executable does not implement `--version`; the attempted
version query correctly exited `1` with an unknown-option diagnostic. Therefore
the tool version is established from the digest-verified official 2.9.4 release
archive and matching official tag, not from a fabricated executable version
string.

The official `generate_keys -p` public lookup attempted in the headless run
exited `1` with `errSecInteractionNotAllowed`. This is a failed secret-backed
Keychain read, not evidence that the key is absent. The public key above was
instead recovered from the non-secret Keychain comment that Sparkle itself
writes for the `SUPublicEDKey` value. No `-x`, `-f`, `-w`, `-g`, private-key
file, secret export, or secret value read was used.

## Stop-The-Line finding: C1 generation provenance is not established

Ceremony C1 began on 2026-07-28 and its accepted outcome says Sparkle 2.9.4
`generate_keys` completed and stored the private key in the login Keychain. The
current matching Keychain item was created on 2026-07-05, 23 days earlier.
Sparkle 2.9.4 source states that default `generate_keys` uses an existing key and
does not overwrite it. The evidence therefore proves that the key exists in the
approved custody store, but it does **not** prove that C1 generated it. The most
likely explanation is that C1 reused the pre-existing July 5 key; this remains
an inference, not an attested historical fact.

No autonomous correction is authorized. Generating or replacing production key
material belongs to `TASK-260728-q5kjta`, and accepting a pre-existing key as
the ceremony key changes the provenance contract. The owner must select one:

1. Amend the C1/task wording to state that C1 adopted and confirmed custody of
   the pre-existing 2026-07-05 key, then retain the public evidence above.
2. Reopen C1 and perform a controlled replacement ceremony, then rerun this
   evidence task against the new public key and creation date. This option must
   account for every downstream pin or secret binding before deleting or
   superseding anything.

Recommendation: choose option 1 only if the owner can attest that the July 5 key
was intentionally created for Relux Works and its pre-C1 custody is acceptable;
otherwise choose option 2. Until that decision, Acceptance Criterion 1 and the
claim “C1-generated keypair” remain unverified.

## Rotation and revocation procedure

### Planned rotation while the old key remains trusted

1. Freeze appcast publication and inventory the installed public key, current
   Developer ID identity, feed-signing settings, CI bindings, and custody grants.
2. Generate a replacement key only in an authorized ceremony, under a distinct
   account/custody record; record only its public key, fingerprint, creation
   date, tool provenance, and custody store name.
3. Keep the existing Developer ID identity unchanged for the transition.
   Sparkle 2.9.4 permits a regular application update to change either the
   EdDSA key or the Apple signing identity, but not both. With
   `SUVerifyUpdateBeforeExtraction`, the transition archive must be a Developer
   ID-signed DMG.
4. Build a transition app whose `SUPublicEDKey` is the replacement public key.
   Sign and validate the transition through the old trust chain, then prove that
   the installed transition validates subsequent payload and appcast signatures
   only with the new key. Missing and wrong keys must fail closed.
5. Only after the transition evidence is accepted, rotate the protected CI
   binding and custody grants, remove the old secret from active signers, retain
   only policy-required recovery material, and rescan every evidence surface.

Steps 3-5 are deliberately not executed or evidenced here. They belong to
`TASK-260728-3bj9bk`.

### Signed-feed boundary

The project requires `SURequireSignedFeed`, pre-extraction verification, and
`SUSignedFeedFailureExpirationInterval=0`. Sparkle documents the expiration as
the recovery fallback when an EdDSA key is lost and a Developer ID-based key
rotation is needed; `0` disables that fallback. A single signed feed also cannot
be assumed to bridge old and new pinned keys without an exercised transition
design. Consequently no emergency signed-feed rotation is claimed here.
`TASK-260728-3bj9bk` must prove the exact old-client/new-client feed transition,
the unchanged-Developer-ID constraint, and negative wrong/missing-key cases
before CI or `SUPublicEDKey` is bound. If it cannot, the owner must change the
feed recovery policy or accept that lost-key recovery requires a separately
authorized distribution path.

### Revocation or suspected compromise

1. Stop publishing immediately; preserve immutable incident evidence without
   copying the private key into tickets, logs, board resources, or the repo.
2. Disable every CI/custody principal that can use the compromised key and
   quarantine affected release candidates. Do not treat deleting the public key
   from a new app as revocation: Sparkle explicitly rejects removal of an
   existing (Ed)DSA key.
3. Determine whether the old private key remains usable and whether the current
   Developer ID identity remains trusted. Never rotate both trust mechanisms in
   one update; stage them separately.
4. Run the authorized replacement ceremony and the downstream transition proof
   above. If the private key is lost/unusable, the signed-feed expiration-0
   boundary is a release blocker until an approved, tested recovery route exists.
5. After accepted migration, remove the compromised secret from active custody
   and CI, document destruction/retention by store name only, invalidate affected
   unpublished artifacts, publish the incident/recovery notice appropriate to
   the release policy, and rerun the leak scan.

Sparkle 2.9.4 exposes rotation behavior, not a network revocation list for an
already embedded `SUPublicEDKey`; operational revocation therefore means
stopping use, removing signer access, and shipping a verified trust transition.

## Leak-scan method and result

The task scan ran after this document and its board outcome were attached. It
treats unreadable or malformed inputs as `unknown`, never as absence. It checks:

- every Git-scoped tracked or non-ignored file in the repository;
- every authoritative board resource, with task run logs reported separately;
- readable zsh history files and session histories;
- private-key PEM/OpenSSH headers, secret-bearing Sparkle export/import or
  signing arguments, credential assignments, private-key paths/files, and
  private-context Base64 candidates.

The scanner emits counts and opaque file identities only, never matching
content. Public-key occurrences are expected non-secret evidence and are not
classified as leaks.

| Scope | Files | Bytes | Private-material candidate files | Key-named files | Read errors |
| --- | ---: | ---: | ---: | ---: | ---: |
| Repository Git scope | 3,042 | 558,496,092 | 0 | 0 | 0 |
| Authoritative board resources | 1,882 | 543,505,479 | 0 | 0 | 0 |
| Task/run logs (also included above) | 764 | 522,060,592 | 0 | 0 | 0 |
| Shell history | 2 | 171,423 | 1 | 0 | 0 |

The final full-scope rescan exited `2`, correctly refusing a clean attestation.
It ran after the outcome was first attached and after board status/checklist
mutations; its counts are the table above. Narrow
classification found two prohibited references in the same shell-history file:

- one real, non-placeholder Sparkle private export command reference, timestamped
  `2026-07-09T22:14:25Z`, using `generate_keys -x` with a `.pem` argument;
- one untimed, non-redacted App Store Connect private-key filename reference.

The command argument and filename are intentionally not reproduced. Structural
scans found no private PEM/OpenSSH block or secret assignment in the repository,
board, or run logs. A read-only Spotlight name lookup for the historical Sparkle
export returned zero indexed matches at exit `0`, but an exhaustive home
filesystem name walk was stopped at the bounded runtime with exit `130`.
Therefore current disk presence of that historical export is **unknown**, not
absent.

This finding independently fails Acceptance Criteria 2 and 5. It also
contradicts C1's accepted statement that shell history had no secret path or key
identifier. Removing or rewriting user shell history and deciding the incident
response are outside this task's authorized scope. Required owner/security input:
authorize a privacy-preserving history remediation and determine whether the
historical Sparkle export and App Store Connect source file need custody
reconciliation or replacement. After remediation, rerun the same full-scope
scan and attach its real exit code before review handoff.

## Fact-checking and sources

- [Sparkle 2.9.4 official release](https://github.com/sparkle-project/Sparkle/releases/tag/2.9.4) — tag, release asset, and vendor archive provenance.
- [Sparkle 2.9.4 `generate_keys` source](https://github.com/sparkle-project/Sparkle/blob/2.9.4/generate_keys/main.swift) — Keychain service/account, public comment, reuse of an existing key, `-p` lookup, and private export/import boundaries.
- [Sparkle signing and key-rotation documentation](https://sparkle-project.org/documentation/#3-segue-for-security-concerns) — custody guidance and the Developer ID/EdDSA rotation constraints.
- [Sparkle customization reference](https://sparkle-project.org/documentation/customization/) — signed-feed failure expiration semantics, including value `0` disabling expiration.
- [`SUUpdateValidator.m` at 2.9.4](https://github.com/sparkle-project/Sparkle/blob/2.9.4/Sparkle/SUUpdateValidator.m) — production validation call site, rotation fallback, refusal to remove EdDSA keys, and one-of-two trust continuity.
- [`SUAppcastDriver.m` at 2.9.4](https://github.com/sparkle-project/Sparkle/blob/2.9.4/Sparkle/SUAppcastDriver.m) — signed-appcast verification and failure-expiration path.
- Board outcomes `TASK-260728-q5kjta_results.md` and
  `TASK-260728-q5kjta_reviewer-verdict-02.md` — accepted C1 claims and dates.
