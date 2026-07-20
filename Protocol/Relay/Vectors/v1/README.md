# Relay protocol v1 conformance vectors

`corpus.json` is the canonical, privacy-safe relay protocol v1 vector corpus.
It is consumed by the Swift `ReluxTunnelCoreTests` and Go
`relay/internal/protocol` test harnesses. Runtime code must not parse this file.

## Stable format

The top-level object has these exact keys:

- `formatVersion`: corpus schema version, currently `1`;
- `protocolVersion`: wire protocol version, currently `1`;
- `provenance`: deterministic generator, source, privacy, and review metadata;
- `vectors`: ordered vector objects.

Each vector has the exact keys `id`, `protocolVersion`, `kind`, `direction`,
`inputHex`, `chunks`, `features`, `limitRefs`, `covers`, and `expected`.
Identifiers are lowercase stable names beginning with `v1.`. `inputHex` is
canonical lowercase hex. A nonempty `chunks` array contains positive byte counts
whose sum is the decoded input size; an empty array means that stream chunking
does not apply.

`kind` is one of `clientHello`, `serverHello`, `envelope`, `envelopeDatagram`,
`datagram`, or `stream`. `expected.outcome` is exactly `success` or `failure`.
A failure carries only the finite `code`, `phase`, `scope`, and `disposition`.
A success carries the decoded hello fields, frame list, or datagram value
applicable to its kind.

Limit metadata never copies numeric policy values. `limitRefs` entries use
`<schema-limit>.<selector>`, where the selector is `floor`, `clientDefault`,
`relayDefault`, `clientHardCeiling`, or `relayHardCeiling`. Both loaders resolve
these references against generated schema metadata.

## Independent oracle and regeneration

The Python-standard-library oracle in `scripts/relay-protocol-vectors.py`
constructs bytes directly with explicit big-endian operations. Its separate
reference parsers audit every expected value or typed failure without importing
or invoking either production codec.

From the repository root:

```sh
make relay-protocol-vectors-generate
make relay-protocol-vectors-check
```

The check builds the corpus twice, byte-compares both results, audits schema
coverage and chunk plans, compares the checked-in file, and prints the vector
count plus SHA-256. It runs as part of `make relay-protocol-check`.

## Review rules

- Never rename or reuse a published vector identifier. Append a replacement so
  review retains the old contract.
- Any edit to existing bytes or expectations must include the protocol schema,
  both generated binding diffs, and both consumer test results.
- A field order/width, length meaning, required sequence, or existing numeric
  value change is incompatible with v1 and requires a parallel new version.
- Review corpus diffs as wire artifacts: identifiers, hex bytes, decoded value
  or finite failure, limit references, coverage tags, and provenance must all
  move together.
- Endpoints and payloads remain synthetic. IPv4/IPv6 values use documentation
  ranges, resolvable-form domains use `.example`, the required one-byte domain
  boundary is the opaque byte `x`, and payload bytes use a fixed public pattern.
