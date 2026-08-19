# Relay supply-chain boundary

The authoritative machine-readable contract is
`relay/supply-chain-source-v1.json`. Its generated provenance and inventory
share a deterministic linkage digest with the exact four-entry relay asset
manifest. The linkage covers the manifest schema, source revision and source
aggregate, build recipe revision and aggregate, toolchain manifest, accepted
archive, and ordered asset size/hash tuples without creating a circular file
hash dependency.

Each fixed component record is checked against authoritative evidence before
generation: relay source and recipe records resolve to pinned Git commits and
file aggregates; the compiler/linker and standard library resolve to the
selected host archive in the pinned toolchain manifest; and each component ID
has one approved SPDX, license-text hash, notice obligation, and distribution
classification. Source URLs must exactly match the component's commit or
version-specific HTTPS allowlist; branches, tags, `latest`, placeholders,
queries, fragments, alternate hosts, and alternate archive names fail closed.

Run the complete read-only audit from a clean checkout:

```sh
make relay-supply-chain-audit
```

Regenerate after an approved metadata/input change, then run the focused tests:

```sh
make relay-supply-chain-generate
make relay-supply-chain-test relay-asset-manifest-test
```

## M2 and M5 ownership

| Control | Milestone | Concrete owner / scope | Evidence / gate |
| --- | --- | --- | --- |
| Source pinning | M2 | Relay build — `TASK-260715-27uz4n` | Full Git revision, repository/relay trees, and SHA-256 for every compiled repository file |
| Build reproducibility | M2 | Relay build — `TASK-260715-27uz4n` | Pinned build-recipe revision, Go compiler/linker archive, no-container base-image declaration, target matrix, environment, and command |
| Asset integrity | M2 | Relay asset packaging — `TASK-260715-1ue4oy` | Accepted archive SHA-256, four ordered executable sizes/hashes, identity, and shared manifest linkage digest |
| License notices | M2 | Relay supply-chain audit — `TASK-260715-vtot05` | Approved SPDX/license hashes and deterministically generated `relay/PRODUCT_NOTICES.txt` |
| Application signing | M5 | Apple release pipeline — `TASK-260715-3sk5cd` | Signed application/archive verification; no signing occurs in the M2 relay build |
| Notarization | M5 | Apple release pipeline — `TASK-260715-387eof` | Submission, acceptance, and staple verification |
| Release attestation | M5 | Release engineering — `TASK-260715-1gzhnk` | Release-level attestation bound to signed deliverables, not this unsigned build provenance |
| Distribution approval | M5 | Release approver — `TASK-260715-312u2k` | Explicit approval for the selected release channel |

M2 produces unsigned, hash-verifiable bundled inputs and never publishes or
installs them independently. M5 consumes those exact inputs and owns all Apple
identity, notarization, release attestation, and distribution decisions.

## Runtime policy

The application may execute only the relay asset selected from its bundled,
generated catalog after the existing size, SHA-256, platform, and identity
checks. Application and relay runtime source may not contain HTTP download
clients or executable-code fetch paths. Tool/archive acquisition remains an
explicit build-host provisioning step using immutable versioned URLs and
SHA-256 verification; build execution itself is offline.

The audit uses an immutable, non-empty static scan contract over `App/`,
`Sources/`, and `relay/` for Swift, Go, Objective-C/C/C++, and header source,
including `.cxx`, `.hh`, `.hpp`, and `.hxx`. Every regular file in those roots
must classify as a scanned source kind, a structurally named Go `_test.go`
file, or one exact reviewed non-runtime path recorded in `runtimePolicy`.
Unknown extensions, new unclassified files, symlinks, missing roots,
empty/partial policy, and a scan that finds no source files fail closed.

The forbidden surface includes Foundation URL/network loaders (including
ambiguous `Data(contentsOf:)` and `String(contentsOf:)`), Objective-C `NSData`
URL selectors, libcurl, C-family `system`/`popen`/spawn/exec entry points,
Swift processes and shell/download commands, Go network/process/plugin imports
and calls regardless of import alias or grouping, and HTTP locators. Explicit
`Data` and `String` reads from `URL(fileURLWithPath:)` remain permitted.
Checks run over comment-free per-language lexical tokens. C-family input also
uses the language's non-nesting block comments, normalizes escaped newlines and
both standard and alternative token-paste spellings, and rejects forbidden
symbol references, aliases, address-taking, and token-pasted fragments. Swift
keeps nested-comment semantics, tokenizes escaped identifiers, inspects normal
and pound-delimited raw-string interpolation, and rejects process type or
ambiguous `contentsOf` constructor references. Objective-C rejects dynamic
selector/reflection paths. Go uses non-nesting block comments, and import
parsing is independent of aliases, grouping, raw strings, and
comment/whitespace placement.
`scripts/` is outside the immutable runtime roots because it is build/test
tooling.

This gate verifies the complete classified repository runtime surface against
the enumerated executable-fetch/download mechanisms. It is not a general
semantic proof for arbitrary future languages: any new or unclassified file
kind fails until the policy and scanner are reviewed together.
