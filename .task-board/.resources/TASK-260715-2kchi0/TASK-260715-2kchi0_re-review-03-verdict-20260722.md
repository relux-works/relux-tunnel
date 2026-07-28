# TASK-260715-2kchi0 re-review-03 verdict

Date: 2026-07-22
Role: independent reviewer
Verdict: changes requested
Route: analysis

## Verdict

Rework-03 correctly fixes the previously reported trailing-LF hashes for the current positive fixture. The task is not accepted because the new jq/JCS equivalence guard is not fail-closed when a schema-valid projected integer expands beyond the ECMAScript safe-integer domain. This directly fails the re-review-03 focus requirement to confirm that the guard fails closed if the fixture domain expands.

## Blocking finding: schema-valid numeric expansion bypasses the guard

The regression in `scripts/tests/TASK-260715-2kchi0_test-m3-jcs-hashes.sh` asserts only that projected keys and strings are printable ASCII and projected numbers satisfy `floor == value`. Those conditions are insufficient for RFC 8785 equivalence. jq 1.8.1 preserves integer tokens outside the IEEE-754 safe range, while RFC 8785 uses ECMAScript binary64 number serialization.

Independent reproduction changed only the projected, schema-v1-valid field `device.installedMemoryBytes`:

```text
value:          9007199254740993
schema:         accepted
current guard:  accepted
jq -cjS SHA256: 3de3ad9f6ceb188631c898b681f49da48406f91e2cb9cbef5486fe53ee4b82cb
JCS SHA256:     30a4024012e2b67f6ba05ab32d6f0085efe4df47b171a5b7e8e3663b1c98ab81
hashes equal:   false
```

The schema has no maximum on this projected integer, so this is not an invalid hypothetical input. Standalone checks also show the same guard accepts `-0` and exponent forms whose jq output is not the ECMAScript/JCS form. The current fixture happens to contain only safe integers, but the executable guard does not prove that property and does not reject a valid expansion that breaks its claimed equivalence.

## Required bounded rework

1. Use a true RFC 8785 implementation for the regression, or strengthen the jq-equivalent-domain guard to reject every non-safe integer and negative zero/unsupported numeric form before hashing.
2. Add an executable negative control based on a schema-valid projected unsafe integer, proving the guard or canonicalizer rejects it rather than hashing non-JCS bytes.
3. Retain the exact positive-fixture and trailing-LF checks, update the fixture expectations/results text, and propagate the test and affected validator/protocol resource copies byte-identically.
4. Rerun the focused hash, schema, copy, privacy, diagram, board, diff, and Swift gates.

## Passing evidence retained

- The current exact projection is 9,373 bytes, ends in `7d`, and independently hashes to `1872767d6f1a5d920db6f7357b43133114a24c2043011131fba44e4bb96b9abb`.
- `runID=m3v1-1872767d6f1a5d920db6f735`, `repetitionID=m3v1-1872767d6f1a5d920db6f735-r01`, and immutable hash `221c543f6dd3cf4a006889afd00ce1a66ea409d1f075dd1c9321852752478fb2` are correct.
- The one-LF form hashes to the former `389a19b5...` value and is rejected.
- Draft 2020-12 metaschema passes. Base, equality, multi-repetition, m=3, and production compositions accept; one-over, hostile, missing-review/statistics, unavailable-measured-pass, and invalid-environment-measured-pass reject.
- Production hostile mutations reject unavailable reviewer/time/classification/group/coverage/comparison, zero candidate count, empty lineage, provisional/blocker/DNS-authority states, false cleanup/privacy gates, and unavailable/red per-metric results.
- The comparison contract remains closed over 16 metric families; m=3 is exact at `59/60` and ranks `83/9916`; latency records simultaneous median/p95/p99.
- Resource declarations match payloads for both tasks. All authored fixture, protocol, schema, diagram, script, and semantic-rule copies tested are byte-identical; the sole empty resource is the declared current reviewer spawn log.
- PlantUML 1.2026.6 check, SVG XML/warning scan, and visual inspection pass.
- `task-board validate`, 57 task references, corrected downstream title, dependency-edge diff, `git diff --check`, logical-reference/privacy scans, and false base DNS/production authority pass.
- `swift test` passes 332 tests in 29 suites; only the previously known linker alignment warning remains.
- No benchmark was run, no tuning winner or DNS production authorization was claimed, and no implementation code was modified during review.
