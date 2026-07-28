# TASK-260715-2kchi0 schema fixture expectations

Ordinary overlays are recursively merged onto
`TASK-260715-2kchi0_valid-pass.json` with `jq -s '.[0] * .[1]'`. The
multi-repetition fixture replaces the base tagged-union `comparison` and
`review.exactCoverage` values so unavailable-only fields cannot leak into the
available variants:

```bash
jq -s '. as $d | ($d[0] * $d[1]) |
  .comparison = $d[1].comparison |
  .review.exactCoverage = $d[1].review.exactCoverage' \
  TASK-260715-2kchi0_valid-pass.json \
  TASK-260715-2kchi0_multi-repetition-valid.overlay.json
```

The m=3 overlay applies to that output, and the production-authorized overlay
applies to the m=3 output. The invalid-environment fixture likewise replaces
`status.exclusion` so the environmental exclusion is structurally valid and
the intended illegal reason code is the rejection. These are schema-v1 and
future semantic-validator inputs, not benchmark results.

The base fixture's semantic identity is verified by the executable regression
`scripts/tests/TASK-260715-2kchi0_test-m3-jcs-hashes.sh`. It applies the exact
section-2 projection and serializes this schema-v1 fixture domain as compact,
sorted UTF-8 JSON with no trailing byte. Before jq can hash, Python lexical
hooks reject duplicate keys, non-plain numeric tokens, negative zero, and every
integer outside `[-9007199254740991, 9007199254740991]`; the recursive guard
also requires printable-ASCII keys/strings. The strict serializer's bytes must
equal `jq -cjS` bytes inside that closed domain. Executable controls prove that
the schema-valid unsafe-positive value `9007199254740993`, negative zero,
decimal `1.0`, and exponent `1e3` are rejected before hashing, as is the
symmetric unsafe-negative value. The script then verifies the unchanged
canonical hash, derived run/repetition IDs, and immutable-manifest hash. A
byte-identical projection with one appended LF must fail the same recorded-hash
check; `jq -cS` is intentionally not accepted.

| Fixture | Expected schema result | Boundary proved |
| --- | --- | --- |
| `TASK-260715-2kchi0_valid-pass.json` | accept | Explicit closed valid pass row with every metric/counter family, artifact/privacy fields, and all safety gates true. |
| `TASK-260715-2kchi0_equality-boundary-valid.overlay.json` | accept | Every selected-SSH DNS hard-envelope maximum and the 65,537-byte connection buffer are accepted at equality. |
| `TASK-260715-2kchi0_one-over-invalid.overlay.json` | reject | Aggregate DNS bytes at 8,388,609 are rejected one byte above the hard envelope. |
| `TASK-260715-2kchi0_hostile-invalid.overlay.json` | reject | Reviewer adversarial shape: claimed pass with failed gates, production authority with blockers/provisional state, unauthorized capture, absolute private path, absent derivative, and invalid monotonic clock shape. UTC ordering is additionally rejected by the semantic validator rule below. |
| `TASK-260715-2kchi0_multi-repetition-valid.overlay.json` | accept | One stable comparison group spans three paired repetition/seed records and every one of the sixteen closed fixed-unit comparison metrics. |
| `TASK-260715-2kchi0_m3-valid.overlay.json` | accept after multi-repetition | Candidate count m=3 is represented exactly as 59/60 coverage and zero-based ranks 83/9916, with no PPM rounding. |
| `TASK-260715-2kchi0_production-authorized-m3-valid.overlay.json` | accept after m=3 | Production authorization has concrete independent review, timestamp, all per-metric classifications, stable group, candidate count, lineage, authority, privacy, and safety gates. |
| `TASK-260715-2kchi0_missing-review-statistics-invalid.overlay.json` | reject | Production authorization cannot use unavailable review/statistics values, an unavailable comparison, or empty accepted-update lineage. |
| `TASK-260715-2kchi0_unavailable-measured-pass-invalid.overlay.json` | reject | `unavailable` cannot claim `measured-pass`. |
| `TASK-260715-2kchi0_invalid-environment-measured-pass-invalid.overlay.json` | reject | A structurally valid environmental exclusion still cannot claim `measured-pass`; it requires `environment-invalidation`. |

`TASK-260721-2ohf99` must also reject the hostile fixture because `utcEnd` is
not later than `utcStart`; JSON Schema cannot compare two independently supplied
date-time strings. It must additionally recompute comparison/candidate IDs,
byte-order sorting, pair membership, candidate-count/coverage/rank equations,
all reported signed effects and bounds, metric directions/units, review time
ordering, immutable lineage hashes, and exact JCS byte termination exactly as
protocol section 10.1 assigns. Numeric-domain validation must occur on source
tokens before a parser/canonicalizer can round, normalize `-0`, or erase
decimal/exponent notation; JSON Schema acceptance does not replace this
semantic gate.
