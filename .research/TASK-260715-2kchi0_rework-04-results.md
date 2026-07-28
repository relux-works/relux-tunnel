# TASK-260715-2kchi0 rework-04 results

Date: 2026-07-22
Role: solution architect
Status: ready for independent review

## Scope and correction

This bounded rework addresses only the fail-open numeric-domain finding in
`TASK-260715-2kchi0_re-review-03-verdict-20260722.md`. The protocol and
validator handoff now require source-token validation before any jq-equivalent
canonicalization. No task or dependency edge was added, no benchmark was run,
no tuning candidate was selected, and production DNS authorization remains
false.

The accepted schema-v1 jq/JCS-equivalent numeric domain is exactly plain
base-10 integer tokens matching `0|-?[1-9][0-9]*`, inclusively bounded by
`-9007199254740991...9007199254740991`. Duplicate keys, negative zero,
decimal/exponent notation, non-finite forms, unsafe integers, and parser
rounding are rejected before hashing. Printable-ASCII keys and strings retain
the already-proved ordering/escaping subset. An independent strict serializer
must emit bytes identical to `jq -cjS`; any difference fails closed.

## Executable regression

`scripts/tests/TASK-260715-2kchi0_test-m3-jcs-hashes.sh` now:

1. parses with lexical hooks that preserve and validate numeric source tokens;
2. rejects duplicate keys and recursively enforces the closed domain;
3. independently serializes the exact section-2 projection and full immutable
   manifest, then compares both byte-for-byte with jq output;
4. proves the schema-valid projected controls
   `installedMemoryBytes=9007199254740993`, `-0`, `1.0`, and `1e3` reject
   before hashing, while asserting each preserved source token's exact expected
   rejection reason;
5. proves the symmetric unsafe-negative value `-9007199254740992` rejects;
6. retains the exact no-trailing-byte positive and one-LF negative checks.

The positive semantic identities remain unchanged:

- `canonicalRowConfigSHA256`:
  `1872767d6f1a5d920db6f7357b43133114a24c2043011131fba44e4bb96b9abb`
- `runID`: `m3v1-1872767d6f1a5d920db6f735`
- `repetitionID`: `m3v1-1872767d6f1a5d920db6f735-r01`
- `immutableManifestSHA256`:
  `221c543f6dd3cf4a006889afd00ce1a66ea409d1f075dd1c9321852752478fb2`
- one-LF mutation SHA-256:
  `389a19b5e967ac58d68c5eacb0054641975065de42853440c18fbe4ffc13a84a`

## Artifact hashes

- protocol:
  `3d67446c3b4223a8500973e4a32a0a0176f219028895a7d45e8dd973875c315a`
- schema (unchanged):
  `e0813d9936ec6acc4bf13acd3c4b8104209ce19401e36a4d3001ce72f74c8fcc`
- valid fixture (unchanged):
  `c11cbb29c76205b7002943817ac501a7e47550b4160f27efecb0c87b6881c44a`
- fixture expectations:
  `f5c5bf1e8f0a683e5d5b4c171eca931c95c2075b10a085692c163fcc507ba834`
- validator semantic rules:
  `3462fac936e8018470af66cfca8377ee145174df18e22b3703321b9a11b98d4e`
- executable regression:
  `25e32770687739f198537cae421feeaac776c6b8277b41ba5bed5df6494230ca`
- PlantUML (unchanged):
  `30e6a166da3532eaf9b0c61861e7f91313d4591ac39230d15885bc9574b9f89e`
- rendered SVG (unchanged):
  `85467a1c431e6c5782bc52e0fa6cd72fff2c72222bf361dd8b62d359cb991308`

## Verification

- Focused numeric/JCS regression: pass. The positive projection and immutable
  manifest match the strict serializer and recorded hashes; all hostile number
  controls and the trailing-LF mutation reject.
- Draft 2020-12 metaschema: pass.
- Base, equality, multi-repetition, m=3, and production compositions: accept.
- One-over, hostile, missing-review/statistics, unavailable-measured-pass, and
  invalid-environment-measured-pass compositions: reject as expected.
- Thirteen production-authority hostile mutations covering unavailable review
  fields, zero candidate count, unavailable coverage/comparison, empty lineage,
  provisional/blocker/DNS states, cleanup, and privacy: reject.
- Exact m=3 arithmetic remains `59/60` with zero-based ranks `83/9916`.
- Copy checks pass for 19 protocol, 6 schema, 3 PlantUML, 1 SVG, 12 fixture
  pairs, both regression copies, and the validator semantic-rule copy.
- PlantUML 1.2026.6 syntax, SVG XML/warning scan, and rendered visual inspection:
  pass; no warning banner or clipping is present.
- All 57 protocol task references resolve; logical references and the focused
  privacy/secret scan pass, with only the named synthetic hostile absolute-path
  control permitted in the scan input.
- `task-board validate`, performance-story planning, `git diff --check`, and
  declared-resource audits pass. The previously recorded broad related-plan
  cycle remains outside this bounded rework.
- `swift test`: 332 tests in 29 suites pass. The known linker alignment warning
  is unchanged.

Production DNS authorization remains false behind accepted selected-SSH,
residual-budget, physical-provider, and independent-review evidence. The
production-positive JSON remains only a contract fixture.
