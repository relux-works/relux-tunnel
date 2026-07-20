# TASK-260715-1q7u14 review verdict

Date: 2026-07-20
Verdict: accepted

The 89-vector canonical relay protocol v1 corpus satisfies AC1-AC5. It has stable lowercase identifiers, protocol version, canonical input hex, relevant chunk plans, structured success or finite typed failure expectations, and generated limit references. Coverage includes both hello layouts and reject boundaries, every generated message and legal direction, all generated address values, every hello status and UDP error value, numeric minimum/maximum neighbor cases, fragmented/coalesced streams, and session/association close plus association reject dispositions.

The Python-standard-library oracle is independent from both production codecs: it constructs explicit big-endian bytes and separately parses/audits expectations without importing or invoking Swift or Go. Reviewer spot checks independently matched fixed hello, IPv4, IPv6, domain, PING, close, and the 1733-byte maximum legal frame-body layouts. The checked corpus is deterministic 2/2, uses only synthetic reserved endpoints and fixed payload patterns, records schema and generator provenance, and documents incompatible edit review rules.

Both strict loaders validate exact corpus/vector/expectation keys, canonical hex, chunk sums, identifiers, schema digest, generated limit selectors, feature names, provenance, and generated coverage. Their negative tests report the exact stable vector identifier with finite reasons and do not print input or payload hex.

Independent validation passed: make relay-protocol-check; uncached CGO_ENABLED=0 Go smoke; swift test --enable-code-coverage --filter RelayProtocol (56 tests); strict swift-format; gofmt; py_compile; shell syntax; git diff --check; task-board validate. Swift affected relay source line coverage is 1784/1915 = 93.16%; Go statement coverage is 85.6%. Corpus SHA-256: e21e6ff50042bd982e8284b579e89a24e66c3437a9b701687ecf707fc57e6e76. Schema SHA-256: 3dd1bc9d8d0c1f9127cad05913137754da61d2657e8d0b8c0b30108e331e8000.

Non-blocking inherited notes: the workstation Go 1.25.5 smoke is not the future Go 1.26.5 release-toolchain gate owned by TASK-260715-27uz4n; the missing ADR-021 row is already recorded in LOGBOOK and does not alter corpus authority or bytes.