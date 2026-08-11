# TASK-260715-29ws8l — macOS SSH profile, trust, and credential boundary contract

- Contract revision: 1
- Contract status: autonomous draft accepted by an independent agent reviewer;
  human ratification is deferred to `TASK-260717-1dsqnj`
- Platform: macOS only; iOS is deferred by ADR-024
- Scope owner: `TASK-260715-29ws8l`
- Selected-engine evidence consumed, not re-decided: ADR-014, ADR-023,
  `TASK-260715-1ozsb6_approved-m0-viability-decision.md`,
  `TASK-260715-1ozsb6_ssh-transport-conformance-contract.md`, and the accepted
  `TASK-260715-1ozsb6_review-results-12.md`
- Credential-transport decision consumed:
  `TASK-260728-7ii1xz_macos-credential-transport-decision.md`, accepted by
  `TASK-260728-7ii1xz_reviewer-verdict-02.md`

## 1. Authority, precedence, and non-goals

This is the production field and ordering contract for one selected macOS SSH
profile. It carries an immutable, non-secret profile snapshot from the
containing app to the root packet-tunnel provider, resolves an opaque
credential reference inside the provider, verifies host identity before any
credential lookup or authentication request, and returns stable typed evidence
or errors.

The accepted macOS transport decision `TASK-260728-7ii1xz` supersedes stale
macOS wording in this task, `.spec/security-privacy.md`, and the older M1
lifecycle contract:

1. The logged-in host and root provider do not resolve one shared App Group
   container. macOS profile transport uses `providerConfiguration`; neither
   side reads or writes an App Group profile snapshot.
2. The macOS provider has no Keychain Sharing entitlement or Keychain access
   group. It uses the provider-owned system-domain file-based Keychain and a
   per-item `SecAccess` ACL constrained to the provider's designated code
   requirement.
3. The complete non-secret snapshot replaces the older macOS
   `configurationReferenceKey` payload that contained only an opaque profile
   identifier. The manager ownership marker and manager-contract marker from
   `TASK-260715-1q4qhw` remain unchanged.
4. Secret seeding/replacement is a separate, explicitly secret-bearing app
   message. Secret bytes never become profile fields, provider configuration,
   start options, diagnostics, logs, crash annotations, or board evidence.
   `SeedCredentialV1` and `RevokeCredentialV1` are the two narrow mutating
   exceptions to the older M1 read-only app-message set; runtime/capability/
   diagnostic commands remain read-only, and profile/trust mutation still does
   not occur through provider RPC.

This contract does not select or fork an SSH engine. It consumes the accepted
libssh2 adapter. It does not define profile editor presentation, key import or
generation, trust-confirmation presentation, password authentication, routing,
multi-lane identity checks, `ProxyJump`, SFTP, agent forwarding, interactive or
arbitrary shell access, or iOS behavior.

## 2. Owners and storage boundaries

| Boundary | Writer / owner | Reader | Persistent location | Allowed content | Forbidden content |
| --- | --- | --- | --- | --- | --- |
| Canonical mutable profile/trust record | Containing app profile repository | Containing app | App-private storage | Non-secret fields in §3, trust history, generations, timestamps | Private key, passphrase, raw host-key bytes |
| Selected immutable provider snapshot | Containing app manager repository; full-object replacement only | Provider configuration loader | `NETunnelProviderProtocol.providerConfiguration[configurationReferenceKey]` | Exact `SSHProfileSnapshotV1` bytes; non-secret metadata, opaque reference, trust records | Any secret, raw observed host key, staging state, free-form error text |
| Start options | Containing app only when it initiates start | Provider start adapter | Ephemeral `startTunnel` options | Optional bounded start request containing the stored snapshot digest and generation | Profile duplication, secret, trust mutation |
| macOS App Group | No owner for this contract | Nobody | None | Nothing | Profile snapshot, reference, secret, trust state |
| Credential system of record | Root provider credential vault | Root provider resolver only | System-domain file-based Keychain item | Versioned credential record containing private-key material and optional passphrase | Identifying attributes; ambient-search-list items |
| Host staging credential | Containing app vault; lifecycle completed by M4 | Containing app seed sender | User-context Keychain staging item | Secret only for the bounded interrupted seed flow | Long-term provider source of truth |
| Runtime credential handle | Provider resolver / external signer | Selected SSH adapter through signing closure only | Memory, bounded to one bootstrap/auth operation | Public key and signature operation; passphrase-decrypted signing state when required | Serializable secret model, diagnostic interpolation, engine-owned persistent copy |
| Runtime host evidence | SSH adapter, then injected host policy | Host policy and bootstrap result | Memory for one bootstrap generation | Negotiated algorithm, raw wire key, canonical SHA-256 fingerprint | General diagnostics, profile persistence before explicit M4 operation |
| Diagnostics | Runtime snapshot owner | Containing app support UI | Bounded runtime snapshot | Stable domain/code/phase, generation, aggregate timings/counts | Host/address, account, credential-reference value, fingerprint, raw key, endpoint, secret, engine prose |

All field names below are public contract names. Actual host, account,
credential-reference, key, passphrase, fingerprint, endpoint, or Keychain path
values must never be copied to board resources or logs.

## 3. `SSHProfileSnapshotV1`

### 3.1 Envelope and encoding

The snapshot is deterministic JSON encoded as UTF-8 with sorted object keys,
no insignificant whitespace, no duplicate keys, maximum nesting depth 8, and
no trailing bytes. Its encoded byte count, including the existing manager
owner and contract metadata in `providerConfiguration`, MUST be at most 4096
bytes. The host validates the bound before saving; the provider validates it
again before allocation or field use.

Unknown object fields are ignored only after byte, depth, UTF-8, duplicate-key,
and type validation, and are dropped when a v1 reader re-encodes the model.
Unknown enum values, missing required fields, or versions other than 1 fail
closed. There is no best-effort downgrade.

### 3.2 Field-level contract

| JSON path | Type / cardinality | Validation and normalization | Owner and generation rule | Storage | Classification |
| --- | --- | --- | --- | --- | --- |
| `protocolVersion` | `UInt16`, required | Exactly `1` | Contract constant; changing semantics requires a new protocol version | Host record and provider snapshot | Non-secret |
| `kind` | string, required | Exactly `sshProfileSnapshot` | Contract constant | Provider snapshot | Non-secret |
| `schemaVersion` | `UInt16`, required | Exactly `1` | New incompatible field semantics require a new schema | Host record and provider snapshot | Non-secret |
| `configurationGeneration` | `UInt64`, required | `>= 1` | Host repository allocates a strictly increasing persisted value for every effective change to any field, credential reference/generation, or trust record; it never reuses or decrements a value | Host record and provider snapshot | Non-secret |
| `profileID` | UUID string, required | Canonical lowercase UUID text; stable for profile lifetime; never derived from user data | Host creates once; profile replacement keeps it, profile deletion retires it | Host record and provider snapshot | Opaque non-secret reference |
| `createdAt` | RFC 3339 UTC timestamp, required | UTC, millisecond precision, valid and `<= updatedAt` | Host sets once | Host record and provider snapshot | Non-secret; prohibited from default logs |
| `updatedAt` | RFC 3339 UTC timestamp, required | UTC, millisecond precision, `>= createdAt`; no future tolerance is used as an authorization decision | Host changes on every effective profile/trust/reference change in the same transaction as generation | Host record and provider snapshot | Non-secret; prohibited from default logs |
| `displayName` | string, required | Unicode NFC; trim surrounding Unicode whitespace; 1...128 Unicode scalars; reject control, line/paragraph separator, and bidi-override scalars | Host/M4 edits; provider never interprets it for identity | Host record and provider snapshot | Non-secret identifying metadata; never diagnostics |
| `canonicalHost.kind` | enum, required | `dns`, `ipv4`, or `ipv6` | Derived by host normalizer; provider independently validates | Host record and provider snapshot | Non-secret sensitive endpoint; never diagnostics |
| `canonicalHost.value` | string, required | Rules in §3.3; 1...253 ASCII bytes for DNS, canonical textual numeric form for IP | Host stores canonical value only; any effective host change increments generation and requires a separate trust decision | Host record and provider snapshot | Non-secret sensitive endpoint; never diagnostics |
| `port` | `UInt16`, required | 1...65535; UI default is 22, but the snapshot never infers a missing value | Host/M4 edits; a change increments generation and is a distinct trust scope | Host record and provider snapshot | Non-secret sensitive endpoint; never diagnostics |
| `account` | string, required | Unicode NFC; trim surrounding whitespace; 1...64 UTF-8 bytes; reject NUL, controls, line separators; preserve case | Host/M4 edits; never participates in host trust identity | Host record and provider snapshot | Non-secret identifying metadata; never diagnostics |
| `credential.ref` | UUID string, required | Canonical lowercase UUID; opaque; never derived from profile, host, account, key, or service attributes | Host vault creates; stable until credential replacement. Replacement is copy-on-write and always allocates a new reference | Host record and provider snapshot; Keychain account selector | Opaque non-secret reference; value never logged |
| `credential.generation` | `UInt64`, required | `>= 1` | Host allocates a strictly newer logical generation for replacement, seeds it under the new reference, and publishes the pair together | Host record, provider snapshot, and inside protected Keychain data | Non-secret control value |
| `hostPolicy.allowedAlgorithms` | ordered unique array, 1...6 | Each value must be in §3.4; canonical order; duplicate or unknown value fails | Host/M4 may narrow but never widen beyond the engine-independent approved set without new reviewed contract evidence | Host record and provider snapshot | Non-secret security policy |
| `hostPolicy.records` | array, 0...8 | Unique `(algorithm, fingerprintSHA256)` tuple; rules in §3.5; deterministic canonical ordering | Only the M4 operations in §10 mutate; each mutation increments configuration generation atomically | Host record and provider snapshot | Non-secret trust data; never default diagnostics |

No snapshot or decoded snapshot model may define fields named or semantically
equivalent to private key, seed, passphrase, decrypted key, key bytes, raw host
key, password, or staging credential. A prohibited-field recursive scan runs
before publication and again after decode.

### 3.3 Canonical host rules

1. Trim surrounding ASCII whitespace before parsing; reject any remaining
   whitespace, NUL, control character, URI scheme, user-info, path, query,
   fragment, bracket, port suffix, or IPv6 zone identifier.
2. Numeric IPv4 accepts only four decimal octets in strict dotted-decimal
   notation, with no sign and no ambiguous leading zero. Re-encode through the
   platform numeric parser to canonical dotted decimal.
3. Numeric IPv6 parses as a bare address and re-encodes in RFC 5952 lowercase
   compressed form. Brackets belong to presentation, never storage.
4. A DNS name is Unicode NFC, mapped with non-transitional UTS #46/IDNA to an
   ASCII A-label, lowercased, and stored without a trailing root dot. Empty
   labels, labels over 63 bytes, total names over 253 bytes, invalid A-labels,
   and names whose round trip is not stable fail validation.
5. DNS and numeric address parsing are mutually exclusive. The provider repeats
   validation and rejects, rather than repairs, a non-canonical stored value.

Host trust scope is the tuple `(canonicalHost.kind, canonicalHost.value, port)`.
Changing any member retains old history only in the host repository; no active
approval is carried into the newly published scope.

### 3.4 Approved host-key algorithms

The v1 engine-independent maximum set, in canonical preference order, is:

1. `ssh-ed25519`
2. `ecdsa-sha2-nistp256`
3. `ecdsa-sha2-nistp384`
4. `ecdsa-sha2-nistp521`
5. `rsa-sha2-512`
6. `rsa-sha2-256`

`ssh-rsa` using SHA-1, DSA, unknown certificate forms, and any algorithm outside
this list are unsupported. A profile may narrow the list. The selected adapter
must also advertise the algorithm; profile permission cannot manufacture an
adapter capability.

### 3.5 Trust records and fingerprint format

Each `hostPolicy.records[]` object has exactly:

| Field | Type | Rule |
| --- | --- | --- |
| `algorithm` | string | One value from `allowedAlgorithms` |
| `fingerprintSHA256` | string | `SHA256:` plus exactly 43 unpadded base64 characters encoding a 32-byte SHA-256 digest of the exact SSH wire public-key blob; canonical base64 alphabet only |
| `state` | enum | `approved` or `revoked` |
| `provenance` | enum | `firstUseApproval` or `changedKeyReplacement` |
| `firstSeenAt` | timestamp | UTC millisecond RFC 3339, set from the matching observed challenge |
| `lastSeenAt` | timestamp | `>= firstSeenAt`; updated only from an exact observed tuple, never from failed or unsupported evidence |
| `approvedAt` | timestamp or null | Required for `approved`; immutable record of explicit approval |
| `revokedAt` | timestamp or null | Required for `revoked`, absent for `approved` |
| `revocationReason` | enum or null | `replaced` or `userRevoked`; required exactly when state is `revoked` |

At most one active approved record may exist in macOS v1. Replacement converts
the old active record to a revoked tombstone and inserts one different active
tuple in a single host-repository transaction. A revoked tuple is never
silently reactivated; v1 refuses reapproval of the same tuple and requires a
future reviewed contract version to define any such recovery.

When eight records already exist, verification still evaluates them normally,
but a replacement requiring a ninth record fails closed with
`trustHistoryFull`. It never drops a tombstone or lowers a changed/revoked
outcome to first use. M4 may offer explicit profile recreation under a new
profile identity and empty trust history; silent compaction is not allowed.

`lastSeenAt` means the latest exact matching observation processed by the host
repository. The provider never mutates trust storage, and a system-started
connection with no host process does not fabricate a newer timestamp. Timestamp
staleness is informational and is never an authorization input.

## 4. Atomic publication and runtime generation

The containing app is the only snapshot writer. Publication is:

1. Serialize profile/trust repository mutations and manager mutations.
2. Validate all fields, prohibited-field scan, total 4096-byte bound, and a
   strictly newer `configurationGeneration`.
3. Deterministically encode the complete snapshot and compute an internal
   SHA-256 digest. The digest is a consistency token, not a diagnostic field.
4. Fresh-load all managers, re-evaluate the accepted owned-manager predicate,
   construct a complete new `NETunnelProviderProtocol`, retain the owner and
   manager-contract markers, and replace `configurationReferenceKey` with the
   snapshot bytes. Never merge unrecognized provider-configuration keys.
5. Save to preferences, reload, and require byte-identical snapshot digest and
   generation. Only then mark the host repository generation published.

The host repository uses one durable `pendingPublication` write-ahead record
containing old and proposed non-secret snapshots, their digests, and the M4
operation ID. The proposed repository mutation is not visible as current until
save/reload verification succeeds. On success it commits the proposed record
and clears the WAL. On definitive failure with the old manager bytes still
verified, it rolls back the proposed record and clears the WAL. After host
crash, recovery fresh-loads the manager before accepting another mutation: a
manager matching the proposed digest commits, one matching the old digest
rolls back, and any third state returns `profilePublicationReconciliationRequired`
without overwriting either source. This is the cross-store atomicity rule for
profile, trust, and credential-reference publication.

A failed save/reload leaves the previous verified published generation
authoritative. There is no App Group file, rename, lock, or cross-container
atomicity claim. NetworkExtension preference replacement, verified reload, and
the host WAL together form the crash-recoverable publication boundary.

At `startTunnel`, the provider copies and validates exactly one snapshot before
credential or route work. Nil start options use that stored snapshot. If a host
start request is present, it carries only `protocolVersion`, `schemaVersion`,
`kind`, `configurationGeneration`, and snapshot digest, is at most 4096 bytes,
and must exactly match the stored snapshot. Mismatch fails
`profileGenerationMismatch`.

The validated value is immutable for the provider runtime generation. A later
manager update never mutates a running generation; the next start captures it.
The runtime's own generation remains distinct from
`configurationGeneration`. A stale callback cannot alter either generation.

## 5. Secret provisioning message contract

The profile path above never contains a secret. A user-authorized M4 credential
save or replacement uses a separate provider message whose content is secret
and therefore is never logged, persisted in manager configuration, retained as
diagnostic data, included in crash reports, or copied to board evidence.

### 5.1 `SeedCredentialV1`

`SeedCredentialV1` is a strict length-prefixed binary codec, not `Codable`,
JSON, a property-list dictionary, or a printable description. Integers are
network byte order. The maximum complete message is 65,536 bytes and nesting is
not supported.

| Field | Binary type / bound | Rule |
| --- | --- | --- |
| `protocolVersion` | `UInt16` | Exactly 1 |
| `schemaVersion` | `UInt16` | Exactly 1 |
| `kind` | `UInt8` | Seed-credential discriminator |
| `requestID` | 16 bytes | Random UUID bytes; correlation/idempotency only |
| `credentialRef` | 16 bytes | Opaque UUID bytes |
| `credentialGeneration` | `UInt64` | Proposed new generation, `>= 1` |
| `privateKeyFormat` | `UInt16` enum | One value from the separately accepted M4 credential-format registry; see below |
| `privateKeyBytes` | `UInt32` length + bytes; 1...49,152 | Exact imported/generated representation; secret |
| `passphrase` | presence + `UInt32` length + bytes; 0...4,096 | Optional UTF-8 bytes; secret; empty is distinct from absent |

The sum of fixed and variable fields must fit the message maximum. Length,
version, unknown format, duplicate request with different bytes, generation,
and trailing-byte validation occurs before Keychain mutation.

Selecting imported/generated key formats is explicitly outside this task and
owned by `TASK-260715-2hhh7x`. Until that task publishes an accepted registry
mapping each nonzero `privateKeyFormat` value to an exact representation,
algorithm, byte bounds, parser, and selected-adapter signer construction, the
v1 registry is empty and production seeding fails closed with
`credentialFormatRegistryUnavailable`. Implementations may build and test the
codec/vault with non-production fixtures, but cannot accept a production seed
by inventing a local format value.

Provider message handling is serialized with credential-vault operations, not
with tunnel start. Every seed is an add under a newly allocated reference;
credential replacement never updates the item named by the currently published
snapshot. A duplicate reference is idempotent only when the protected record's
request ID, credential generation, format, and secret-payload digest all match;
otherwise it returns `credentialReferenceCollision` and changes nothing. The
response is a non-secret
`CredentialMutationResponseV1` of at most 4096 bytes containing version, kind,
request ID, `stored|idempotent` outcome, stored credential generation,
and a stable error code if applicable. It contains no key-derived or
passphrase-derived data.

The provider may be launched to handle this message while the tunnel is not
started. This does not imply the system VPN is connected. Failure to deliver is
reported; the host retains its bounded staging item until an explicit retry or
user cancellation under the M4 lifecycle contract.

Create and replacement use this copy-on-write sequence:

1. Host allocates a new opaque reference, a newer logical credential
   generation, and a request ID; it does not alter the current profile.
2. Provider stores the new exact item and confirms its generation.
3. Host stages the new `(ref, generation)` in the §4 publication WAL, publishes
   and verifies the complete new snapshot, then commits the host record.
4. Only after verified publication does the host request revocation of the old
   reference. A pending revocation is surfaced using §11; it does not roll back
   the now-authoritative new credential.

If step 2 fails, the old snapshot/item remain authoritative. If step 3
definitively rolls back, the host revokes the orphan new item; a lost cleanup is
also caught by the crash-recovery sweep. A crash after manager publication is
resolved from the WAL before another mutation. A crash after publication but
before step 4 leaves the new credential usable and the old item as removable
residue; the sweep deletes the old item because its reference is absent from the
current profile set. No failure mode mutates the secret behind the previous
published reference.

### 5.2 `RevokeCredentialV1`

This message is non-secret but reference-sensitive, deterministically encoded,
and at most 4096 bytes. It contains protocol version 1, schema version 1, kind,
request ID, opaque credential reference, and optional expected credential
generation. The provider performs an exact scoped delete and responds with
`revoked` or `alreadyAbsent`; both mean lookup now fails in that provider state.
A generation mismatch returns a stable conflict and deletes nothing.

Replacement is copy-on-write seed, verified profile publication, then revoke.
It never opens a window where a failed write has already destroyed or changed
the credential behind the previous published reference.

## 6. System-domain Keychain query and ACL contract

Every operation first resolves the system-domain default Keychain using
`SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem, ...)`. No Keychain
path literal is stored, logged, or embedded. Failure to resolve is terminal for
that operation.

The item class is generic password. Its attributes are limited to a fixed,
non-identifying service constant and `account = credentialRef`. Attributes must
not contain host, display name, SSH account, profile identifier, fingerprint,
key algorithm, provenance, timestamp, or credential generation because
file-based Keychain attributes can be read by unprivileged local users.
Credential generation and format live inside the protected item data.

The Keychain item data is exactly `CredentialRecordV1`, a strict
length-prefixed binary codec with network-byte-order integers and a maximum of
57,344 bytes. It is not `Codable`, JSON, a property list, or printable. Its
fields, in order, are:

| Field | Binary type / bound | Classification and validation |
| --- | --- | --- |
| `magic` | 8 fixed bytes | Non-secret ASCII `RLXCRD1` followed by one zero byte; exact match required |
| `recordVersion` | `UInt16` | Non-secret; exactly 1 |
| `credentialRef` | 16 bytes | Opaque non-secret; must equal the query account selector |
| `credentialGeneration` | `UInt64` | Non-secret control; must equal the snapshot on lookup |
| `seedRequestID` | 16 bytes | Opaque non-secret idempotency token |
| `privateKeyFormat` | `UInt16` | Non-secret enum; must exist in the accepted registry |
| `privateKeyBytes` | `UInt32` length + 1...49,152 bytes | Secret; format-specific length/parser must also pass |
| `passphrase` | presence byte + `UInt32` length + 0...4,096 bytes | Secret; empty and absent remain distinct |
| `secretPayloadDigest` | 32 bytes | Secret-derived, sensitive verifier stored only inside protected item data; SHA-256 over the canonical bytes from `privateKeyFormat` through `passphrase` |

The decoder rejects wrong magic/version, overflow, truncation, trailing bytes,
oversize fields, reference/generation mismatch, unavailable/unknown format,
format-specific parse failure, and payload-digest mismatch before constructing
a signer. It never performs format guessing or fallback. The provider is the
only writer and reader. Idempotency compares request ID, reference, generation,
format, and the protected digest in constant time where the Security/Crypto API
permits; the digest is never returned, logged, or placed in attributes.

The add query contains the resolved `SecKeychainRef` under `kSecUseKeychain`.
Copy, update, and delete queries contain a one-element array with that same ref
under `kSecMatchSearchList`. Every operation sets
`kSecUseDataProtectionKeychain` to false. Copy/update/delete use the exact item
class, fixed service constant, and opaque account, and use a match limit of one
where applicable. Ordinary seed, lookup, update, and revoke operations never
enumerate, use the ambient search list, or fall back to another item.

The item is created with `kSecAttrAccess` set to a restrictive `SecAccess`
whose trusted application is built from the installed provider's designated
code requirement. A requirement-construction or ACL failure aborts the write.
No user-consent prompt is accepted as a background fallback.

`kSecAttrAccessGroup`, Keychain Sharing, and `kSecAttrAccessible` are absent:
they belong to the Data Protection Keychain and are inapplicable to this macOS
file-based path. Synchronization/export is unsupported. The system-domain item
is available for unattended root-provider start, but macOS cannot offer user
login-password protection for this secret at rest. The contract makes no claim
that a privileged local attacker or compromised provider cannot read it.

`startTunnel` is read-only: it performs an exact query and never seeds,
replaces, deletes, repairs, prompts, or waits for the host. A miss returns
`credentialNotProvisioned` immediately. At provider process start, before a
tunnel generation begins, a bounded reconciliation sweep may delete items
whose opaque references are absent from the current installed profile set. The
sweep is crash-recovery cleanup only, never the normal revocation path. It uses
the same resolved system-domain Keychain and the following sole enumeration
exception:

1. The credential-vault actor serializes the sweep against seed/revoke/lookup.
   It first fresh-loads and fully validates the installed profile snapshot. If
   the snapshot/profile set is missing, corrupt, future-versioned, or otherwise
   unknown, it performs no enumeration or deletion and returns
   `credentialReconciliationProfileSetUnavailable`.
2. It calls `SecKeychainSearchCreateFromAttributes` to create a
   `SecKeychainSearch` scoped directly to the resolved system-domain
   `SecKeychainRef`, generic-password class, and the one fixed provider service
   constant. `SecKeychainSearchCopyNext` yields one item at a
   time; no ambient or cross-Keychain search is allowed.
3. It processes at most 32 items per cooperative batch and 256 items per
   provider launch. The search cursor exists only in provider memory between
   batches. End-of-search completes the sweep. Reaching 256 discards the cursor,
   emits only `credentialReconciliationLimitExceeded` plus aggregate counts,
   and leaves another bounded pass for the next provider launch; it does not
   claim cleanup completion.
4. For each candidate, it reads only class, service, and account attributes,
   verifies the fixed service and canonical opaque-reference form, and compares
   the account in memory with the validated current-profile reference set. An
   exact current reference is retained. Any other well-formed reference is a
   stale provider-owned item and is deleted through `SecItemDelete` using exact
   class/service/account plus `kSecMatchSearchList` containing only the resolved
   system-domain ref. A malformed account under the provider-owned fixed
   service is also deleted as corrupt residue; no item from another service is
   eligible.
5. The enumerated account value is released after the single comparison/delete
   and is never retained across items, returned, logged, measured, or placed in
   an error. Only scanned/retained/deleted/malformed counts and stable status may
   leave the vault actor. A per-item error stops the sweep with
   `credentialReconciliationFailed`; it never broadens the predicate.

Because this task carries one installed selected profile, each capped pass
retains at most one current item and can delete the remaining stale candidates;
repeated launch passes therefore make progress without a persisted sensitive
cursor. The sweep remains cleanup defence and does not turn deletion into an
enumeration-based normal path.

## 7. Credential lifetime, passphrase, cancellation, and clearing

1. The host keeps seed-message secret bytes only through message encode/send/
   response or cancellation, then overwrites owned mutable buffers and releases
   all references. A staging Keychain item may survive interruption only under
   the explicit M4 staging lifecycle; successful provider storage deletes it.
2. The provider copies message bytes into the minimum mutable buffers needed to
   validate and store, then overwrites them and releases references after the
   Keychain result. It never caches seed requests.
3. The credential resolver retrieves item data only after host trust is
   approved. It decodes credential generation, format, key, and optional
   passphrase inside one lexical/asynchronous credential scope.
4. If the accepted key format is encrypted, decryption and passphrase handling
   occur inside that scope. A passphrase is never returned as a standalone
   public value. The selected SSH adapter receives public-key material and an
   external signing closure, not private-key or passphrase bytes.
5. Cancellation before a synchronous Security operation prevents it from
   starting. Once a Security call has begun it is not claimed cancellable; a
   cancellation observed on return discards the result, clears owned buffers,
   and prevents authentication. Cancellation during authentication retires the
   signer and clears/relinquishes its state before bootstrap cleanup completes.
6. Mutable byte buffers are overwritten before deallocation where the selected
   API exposes writable storage. Immutable `Data`, Swift copies, IPC copies,
   Security framework internals, allocator copies, crash dumps, and engine
   internals cannot be proven zeroized. The guarantee is bounded lifetime and
   best-effort clearing, never perfect zeroization.

## 8. Mandatory host-verification ordering and outcomes

The accepted libssh2 evidence proves this seam can expose exact raw host-key
evidence before credential lookup and authenticate through an opaque external
signer. Every bootstrap follows this order:

1. Decode and validate the immutable profile snapshot and generation.
2. Resolve and connect the canonical host/port on the physical path; do not
   install routes or start forwarding.
3. Complete SSH key exchange far enough to receive `HostKeyEvidence` containing
   the exact negotiated host-key algorithm and raw SSH wire public-key blob.
4. Give that evidence to the injected host policy. The policy computes the
   canonical SHA-256 fingerprint from the raw blob and applies this exact
   decision order:
   a. algorithm absent from the profile allow-list, the approved maximum set,
      or selected-adapter capabilities -> `unsupported`;
   b. exact tuple matches a revoked record -> `revoked`;
   c. exact tuple matches the active approved record -> `approved`;
   d. `hostPolicy.records` is empty -> `firstUse`;
   e. otherwise, including a history containing only revoked tombstones ->
      `changed`.
5. For `approved` only, query and decode the exact credential item and require
   its generation to equal the snapshot.
6. Ask the external signer to authenticate. No password, agent, file-path, or
   downgraded algorithm fallback exists.
7. On success return `SSHBootstrapEvidenceV1`; only later runtime stages may
   prepare consumers or routes.

| Host-policy outcome | Stable bootstrap result | Authentication / route effect | Sensitive UI evidence |
| --- | --- | --- | --- |
| `firstUse` | `hostTrustRequired` | Stop before credential lookup; no retry and no routes | M4 obtains one bounded `TrustChallengeV1` through the probe operation below |
| `approved` | Continue | Credential lookup and public-key auth may begin | None |
| `changed` | `hostKeyChanged` | High-severity fail before credential lookup; no automatic accept/retry and no routes | M4 obtains a high-severity bound challenge through the probe operation below |
| `unsupported` | `hostKeyAlgorithmUnsupported` | Fail before credential lookup; no downgrade and no routes | Algorithm identifier only on the private trust UI channel |
| `revoked` | `hostIdentityRevoked` | Fail before credential lookup; no reactivation/retry and no routes | No fingerprint required; a matching local record already exists |

The ordinary `startTunnel` failure carries only the stable code; it never puts a
fingerprint in `NSError` or disconnect diagnostics. To display a first-use or
changed key, M4 sends a read-only `ProbeHostIdentityV1` app message.

`ProbeHostIdentityV1` is deterministic sorted-key UTF-8 JSON, maximum 4096
bytes and depth 2, with exactly these required fields and no optional fields:

| Field | Type / bound | Rule / classification |
| --- | --- | --- |
| `protocolVersion` | `UInt16` | Exactly 1; non-secret |
| `schemaVersion` | `UInt16` | Exactly 1; non-secret |
| `kind` | string | Exactly `probeHostIdentity`; non-secret |
| `requestID` | canonical UUID string | Opaque correlation token; never diagnostic |
| `profileID` | canonical UUID string | Opaque selected-profile binding; never diagnostic |
| `expectedConfigurationGeneration` | `UInt64 >= 1` | Exact compare-and-swap input |

The request decoder first enforces the byte/depth/UTF-8 bounds, rejects
duplicate or unknown keys, missing keys, wrong JSON types, noncanonical UUIDs,
numbers outside the declared integer ranges, insignificant trailing bytes, and
any generation/profile mismatch, and performs no network or credential side
effect on rejection. There is no downgrade or unknown-field compatibility in
this security-sensitive v1 control request.

The provider validates the current stored snapshot, opens a bounded SSH
connection, performs only steps 2–4 above, closes it without credential lookup,
authentication, or routes, and returns either the exact `TrustChallengeV1`
below for `firstUse|changed`, or deterministic `TrustProbeStatusV1` JSON for an
already `approved`, `revoked`, or `unsupported` result. `TrustProbeStatusV1`
uses the same 4096-byte/depth-2/exact-key decoder rules and contains exactly
`protocolVersion=1`, `schemaVersion=1`, `kind=trustProbeStatus`, the copied
`requestID`, `profileID`, `configurationGeneration`, `outcome` in
`approved|revoked|unsupported`, and required `stableCode` whose value is the
matching stable bootstrap code for rejected outcomes and JSON `null` exactly
for `approved`. It also contains required `observedAlgorithm`: for
`unsupported` this is the exact observed SSH algorithm token, constrained to
1...64 printable ASCII bytes with no whitespace/control; for `approved` and
`revoked` it is JSON `null`. No status response carries a fingerprint.
Configuration/network/policy failures return the bounded
stable `protocolError` envelope from the accepted M1 contract, with the copied
request ID and no raw error text. Messaging may launch a stopped enabled
provider; success means only that the probe completed, never that the VPN
connected.

`TrustChallengeV1` is deterministic sorted-key UTF-8 JSON, maximum 4096 bytes,
maximum depth 4, and has exactly these fields:

| Field | Type / rule | Classification / owner |
| --- | --- | --- |
| `protocolVersion`, `schemaVersion` | `UInt16`, exactly 1 | Non-secret constants; provider writes |
| `kind` | string, exactly `trustChallenge` | Non-secret discriminator; provider writes |
| `outcome` | `firstUse` or `changed` | Security-sensitive; provider host policy writes |
| `requestID` | canonical UUID | Opaque correlation; copied from probe |
| `challengeID` | canonical random UUID | Opaque one-use token; provider creates |
| `profileID` | canonical UUID | Opaque profile binding; copied from snapshot |
| `configurationGeneration` | `UInt64 >= 1` | Exact snapshot CAS binding |
| `trustScopeDigest` | `SHA256:` canonical 43-character unpadded base64 digest | Sensitive binding, never diagnostic |
| `expectedTrustStateDigest` | same digest form | Sensitive CAS binding, never diagnostic |
| `observedAlgorithm` | approved algorithm string | Security-sensitive UI evidence |
| `observedFingerprintSHA256` | canonical §3.5 form | Security-sensitive UI evidence |
| `observedAt` | UTC millisecond RFC 3339 | Display/audit time; not an authorization clock |
| `validForMilliseconds` | `UInt32`, exactly 300000 | Fixed five-minute monotonic host lifetime |

All fields are required. Its decoder uses the same reject-duplicate,
reject-unknown, exact-type/range, canonical-UUID, no-trailing-byte rules as the
probe request and additionally validates the fingerprint/digest canonical forms
before exposing any UI value.

`trustScopeDigest` is SHA-256 over a version-1 length-prefixed binary encoding
of host-kind byte, canonical-host UTF-8 byte length/value, and network-order
port. `expectedTrustStateDigest` is SHA-256 over a version-1 length-prefixed
binary encoding of the ordered allowed-algorithm strings followed by every
trust record sorted by algorithm bytes then raw 32-byte fingerprint digest;
each record contributes algorithm length/value, raw digest, and one state byte.
Provenance and timestamps are excluded because they do not authorize a key.

The containing app owns at most one in-memory challenge per profile. Receipt
starts a monotonic five-minute deadline; a newer probe invalidates the prior
challenge. Challenges are not persisted, restored, logged, or placed in crash
state. The M4 repository operation requires an unexpired in-memory challenge,
exact profile/generation/scope/trust-state digest match, and matching operation
outcome. Successful verified publication consumes it. A failed publication may be
retried only while the same CAS values and deadline remain; process loss,
expiry, mismatch, or success requires a new probe. Generation change makes any
replay fail even if an old token is presented.

Raw host-key bytes never leave the provider host-policy scope and never enter a
challenge. A challenge is non-secret but security-sensitive, is never a general
diagnostic, and is valid only for its one bound observation.

## 9. Stable bootstrap evidence and errors

`SSHBootstrapEvidenceV1` is an internal, non-`Codable` provider-ready value:

| Field | Meaning / handling |
| --- | --- |
| `profileID` | Opaque selected profile binding; never diagnostic |
| `configurationGeneration` | Exact immutable snapshot generation |
| `verifiedHostIdentity.algorithm` | Exact approved negotiated algorithm |
| `verifiedHostIdentity.fingerprintSHA256` | Exact approved canonical fingerprint; never default diagnostic |
| `credentialGeneration` | Exact Keychain generation used for authentication |
| `actualEndpoint` | Resolved/connected numeric address and port for later narrow route ownership; internal only, never diagnostic |
| `authenticatedSession` | Selected-engine session handle owned by the runtime generation |

Success is emitted only after host approval and successful public-key
authentication. Evidence values are not proof of a shipped VPN and are never
rendered through default `description`, reflection, crash annotation, or
metrics.

Stable errors use domain `sshProfileBootstrap`, a code, and phase only. They
carry no underlying engine prose. Required codes are:

- configuration: `profileOversize`, `profileCorrupt`,
  `profileVersionUnsupported`, `profileInvalidField`,
  `profileGenerationMismatch`, `profileContainsProhibitedField`,
  `profilePublicationReconciliationRequired`;
- trust: `hostTrustRequired`, `hostKeyChanged`,
  `hostKeyAlgorithmUnsupported`, `hostIdentityRevoked`, `hostPolicyRejected`,
  `trustChallengeExpired`, `trustChallengeMismatch`, `trustHistoryFull`;
- credential: `credentialNotProvisioned`, `credentialAccessDenied`,
  `credentialGenerationMismatch`, `credentialMalformed`,
  `credentialPassphraseRequired`, `credentialPassphraseInvalid`,
  `credentialKeyUnsupported`, `credentialMutationConflict`,
  `credentialReferenceCollision`, `credentialFormatRegistryUnavailable`,
  `credentialReconciliationProfileSetUnavailable`,
  `credentialReconciliationLimitExceeded`, `credentialReconciliationFailed`;
- authentication/lifecycle: `authenticationRejected`,
  `operationCancelled`, `operationTimedOut`, `internalInvariant`.

Only `hostTrustRequired` and `hostKeyChanged` may have a separately typed trust
challenge on the private M4 channel. Diagnostics store only domain, code,
phase, configuration generation, retry class, and aggregate timing. They MUST
NOT store or interpolate host/address, display name, SSH account,
credential-reference value, fingerprint, raw key, passphrase, endpoint,
Keychain path, request bytes, or raw platform/engine error text.

The three `credentialReconciliation*` codes are bounded cleanup statuses, not
substitutes for the exact credential lookup result and not claims that cleanup
completed. `ProfileSetUnavailable` means the sweep made no query/deletion;
`LimitExceeded` means the capped pass ended with possible residue; `Failed`
means one scoped enumeration/delete operation failed and the sweep stopped
without broadening its predicate. They do not by themselves fail an otherwise
valid exact current-reference lookup or authenticated tunnel start because the
sweep is crash-recovery defence, not the authorization path. If the current
profile is itself invalid, the independent profile error remains terminal.
Diagnostics may emit the reconciliation code, phase, and aggregate
scanned/retained/deleted/malformed counts only. M4 projects either non-complete
status as pending cleanup and never as successful revocation.

## 10. M4 trust-operation handoff

`TASK-260715-2hhh7x` owns UI presentation and the following two exact repository
operations. They are the only v1 operations that create or replace approved
trust:

1. `approveFirstUseTrust(profileID:expectedConfigurationGeneration:challengeID:expectedTrustStateDigest:)`
   requires an unexpired `hostTrustRequired` challenge whose profile and
   generation, scope digest, and trust-state digest match, re-displays the full
   algorithm/fingerprint for explicit user action, creates the one active record with
   `provenance=firstUseApproval`, increments generation, publishes the full
   snapshot, and consumes the challenge. It never reconnects automatically.
2. `replaceApprovedTrust(profileID:expectedConfigurationGeneration:challengeID:expectedTrustStateDigest:)`
   requires an unexpired high-severity `hostKeyChanged` challenge and exact
   compare-and-swap of generation, scope digest, and complete authorization-state
   digest. One §4 WAL-backed transaction
   tombstones the prior active record as `revoked/replaced`, inserts the observed
   tuple with `provenance=changedKeyReplacement`, increments generation,
   publishes, and consumes the challenge. Conflict or publication failure
   changes no trust. It never reconnects automatically.

M4 may separately define display, confirmation text, profile deletion, and
user-initiated trust revocation, but cannot bypass these compare-and-swap and
publication rules. Human governance ratification remains decoupled under
`TASK-260717-1dsqnj`; accepted autonomous implementation may consume this
agent-reviewed draft before that later physical-acceptance checkpoint.

## 11. Five-state credential revocation and uninstall residue

| State | Provider condition | Delivery result | Contract outcome |
| --- | --- | --- | --- |
| 1 | Configuration installed and enabled; provider stopped | App message is documented to launch the provider | Synchronous `completed` when the provider response confirms delete/already-absent |
| 2 | Configuration installed and enabled; provider running | Live provider handles message | Synchronous `completed` when response confirms delete/already-absent |
| 3 | Configuration disabled | Send fails with configuration-disabled platform error | `pendingDisabled`; reconciliation sweep may complete on a later start |
| 4 | Configuration missing/invalid, provider unapproved/superseded/activation failed, or no manager exists | Send fails with configuration-invalid platform error or cannot be addressed | `pendingInvalid`; reconciliation may complete after valid reinstall/start |
| 5 | No containing-app host process is running | No app-side actor originates a request | No completion claim; state remains pending/unrequested |

The containing app and M4 UI must never map states 3–5 to completed. The
documented launch-on-message behavior is retained as a physical verification
trigger; contradictory physical evidence narrows states 1–2 to pending rather
than changing the Keychain source-of-truth or read-only-start rules.

Uninstalling the system extension removes its container but not the
system-domain Keychain item. Uninstall therefore can leave credential residue.
The supported recovery is reinstall/enable then explicit revoke or
reconciliation sweep. A separately authorized uninstall tool may perform an
explicit root cleanup using the same resolved-domain, exact-service/account,
designated-requirement rules. The product must disclose pending residue; it
must not claim that container removal or ordinary unprivileged app deletion
erased the system-domain secret.

## 12. Security-requirement trace

| Requirement | Contract enforcement | Evidence / consumer |
| --- | --- | --- |
| `.spec/security-privacy.md` host-key verification before user auth | §8 steps 3–5; every non-approved outcome stops before credential lookup | ADR-023 M0 row `Host key before authentication`; accepted libssh2 review round 12 |
| Canonical host plus approved algorithms/fingerprints/provenance/timestamps | §§3.2–3.5 | Profile loader `TASK-260715-3f4lxy`; M4 `TASK-260715-2hhh7x` |
| Explicit first use and changed-key replacement; no silent checking disable | §§8 and 10 | M4 operations; trust-policy implementation task `TASK-260715-12zaq5` |
| Secrets absent from provider configuration/logs/board | §§2, 3, 5, 9 | Vault/resolver tasks `TASK-260715-379cpk` and `TASK-260715-1o9wjz`; redaction task `TASK-260715-1i49fm` |
| macOS credential reality superseding stale DP-Keychain claim | §§1, 5–7, 11 | Accepted `TASK-260728-7ii1xz`; entitlement matrix `TASK-260715-ypo7yo` |
| Stable privacy-safe SSH errors | §9 | Accepted M0 conformance rows E-ERRORS and E-METRICS-PRIVACY |
| No routes before trust/auth | §8 and every failure row | Accepted M1 runtime contract `TASK-260715-30zng6` |
| Honest protection claims | §§6–7 and 11 state no login-password-at-rest or perfect-zeroization guarantee | `.spec/security-claims.md` SC-04/SC-05 and prohibited overclaim rules |

## 13. Consumer map and dependency handoff

| Consumer | Exact handoff |
| --- | --- |
| `TASK-260715-3f4lxy` profile loader | Implement deterministic 4096-byte `providerConfiguration` snapshot decode, canonical validation, prohibited-field scan, immutable generation capture, and no App Group read |
| `TASK-260715-1o9wjz` provider credential resolver | Implement §6 exact system-domain query, ACL, read-only start, generation match, error mapping, cancellation, and best-effort clearing |
| `TASK-260715-379cpk` app credential vault | Implement staging plus seed/revoke messages, five-state outcomes, and no bare-success revocation API |
| `TASK-260715-12zaq5` host policy | Implement §8 raw-evidence decision order and first-use, approved, changed, unsupported, and revoked trust outcomes before credentials |
| `TASK-260715-13labb` bootstrap error mapping | Implement §9 stable bootstrap errors, retry classes, and diagnostic redaction |
| `TASK-260715-297imp` composed integration matrix | Consume the composed profile-driven SSH contract across profile loading, host policy, credential resolution, error mapping, and runtime ordering |
| `TASK-260715-2hhh7x` M4 profile/key/ownership contract | Adopt §10 exact operations, staging/replacement/revocation UI states, and platform-specific custody language |
| `TASK-260715-30zng6` / M1 composition consumers | Treat this macOS snapshot field shape as the superseding `ConfigurationSnapshotSource`; preserve one-generation ownership and no-route ordering |
| `TASK-260717-1dsqnj` ratification | Record the exact accepted contract resource, reviewer verdict, and digest later; ratification does not block autonomous implementation |

Existing board dependencies already make implementation consumers wait for this
contract and the accepted transport/identifier decisions. No new dependency or
board element is needed.

## 14. Completeness, gap, and scope audit

- The task is already the smallest atomic deliverable: one field/storage/trust/
  credential boundary contract. No child task, story, research task, or diagram
  was created.
- Every literal task requirement maps to §§2–13. The stale App Group,
  accessibility, and access-group requirements are not silently omitted; §1
  records the accepted macOS supersession and §§2/6 state the replacement.
- Beyond-literal material is limited to the exact gaps proved by accepted
  `TASK-260728-7ii1xz`: system-domain transport, app-message mutation schemas,
  five-state revocation, uninstall residue, and non-identifying attributes.
  Out-of-scope checks found existing owners for implementation, M4 UI, physical
  verification, spec correction, and human ratification, so no new board item
  is justified.
- No genuinely open research question remains in this contract. The only
  platform uncertainty, physical launch-on-message behavior, already has an
  existing physical verification owner and a fail-safe contract outcome in
  §11; creating another research task would duplicate that owner.
- Profile editor UI, key formats/import/generation, password auth, routing,
  engine selection/forking, multi-lane enforcement, `ProxyJump`, and arbitrary
  shell access were checked and remain out of scope.
- No planning artifact or diagram was produced. The contract and handoff
  evidence are the only required task-scoped outcomes.
