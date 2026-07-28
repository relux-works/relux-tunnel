# TASK-260715-2kchi0 rework-03 results

Date: 2026-07-22
Role: solution architect
Status: ready for independent review

## Scope and correction

This bounded rework addresses only the RFC 8785 fixture-hash defect in
`TASK-260715-2kchi0_re-review-02-verdict-20260722.md`. The base positive fixture
now hashes the exact compact JCS bytes with no trailing LF, derives its run and
repetition identities from that hash, and hashes the corrected immutable row.
No protocol policy, schema shape, diagram, task, dependency edge, benchmark,
tuning selection, or production/DNS authority was changed.

Corrected semantic values:

- `canonicalRowConfigSHA256`:
  `1872767d6f1a5d920db6f7357b43133114a24c2043011131fba44e4bb96b9abb`
- `runID`: `m3v1-1872767d6f1a5d920db6f735`
- `repetitionID`: `m3v1-1872767d6f1a5d920db6f735-r01`
- `immutableManifestSHA256`:
  `221c543f6dd3cf4a006889afd00ce1a66ea409d1f075dd1c9321852752478fb2`

## Executable regression and downstream handoff

`scripts/tests/TASK-260715-2kchi0_test-m3-jcs-hashes.sh` applies the exact
protocol section-2 projection. Before using `jq -cjS`, it fails unless every
projected key and string is printable ASCII and every number is an integer;
that closed schema-v1 domain makes jq's UTF-8 key ordering, escaping, and
integer rendering byte-equivalent to RFC 8785 JCS. The regression then:

1. accepts the positive fixture's corrected canonical hash;
2. derives and checks `runID` and `repetitionID`;
3. proves the exact object ends in `7d`, with no trailing byte;
4. creates the `jq -cS` one-LF negative control and rejects it against the
   recorded hash while confirming its historical fingerprint; and
5. recomputes and accepts the corrected immutable-manifest hash.

The source script is executable and byte-identical copies are attached to
`TASK-260715-2kchi0` as outcome evidence and to `TASK-260721-2ohf99` as a
mandatory validator precondition. The corrected base fixture and expectations
are likewise byte-identical across both task resources. The validator's dated
semantic contract now explicitly rejects BOMs, LF/CR, record separators,
whitespace, or any other trailing byte.

## Artifact hashes

- protocol (unchanged):
  `d2e6fec9f6f2715669df41f929bb3f2cc64ae391136b748f5ae387c4b373eb32`
- schema (unchanged):
  `e0813d9936ec6acc4bf13acd3c4b8104209ce19401e36a4d3001ce72f74c8fcc`
- corrected valid fixture:
  `c11cbb29c76205b7002943817ac501a7e47550b4160f27efecb0c87b6881c44a`
- updated fixture expectations:
  `6dedfcec4fca7e5d0cd372f4fa88cd263fcac09a0d7de219c0207b656dae9607`
- updated validator semantic rules:
  `a1e10dbb2e1fe38c1146288c0c65097cd478576bd39a3f3f15b042ec6b1d8618`
- JCS regression:
  `b9583b03878a10e10a26c7bdff44a23539d1c16d471852840ff728289c339441`
- PlantUML (unchanged):
  `30e6a166da3532eaf9b0c61861e7f91313d4591ac39230d15885bc9574b9f89e`
- rendered SVG (unchanged):
  `85467a1c431e6c5782bc52e0fa6cd72fff2c72222bf361dd8b62d359cb991308`

## Verification

- Exact JCS/no-LF semantic regression: pass; positive accepted, LF mutation
  rejected, canonical/derived/immutable identities equal the values above.
- Draft 2020-12 metaschema and base/equality/multi-repetition/m=3/production
  positive compositions: pass.
- One-over/hostile/missing-review-statistics/unavailable-measured-pass/
  invalid-environment-measured-pass compositions: reject as expected.
- m=3 remains exact: one stable group, three paired records, `59/60`, and
  zero-based ranks `83/9916`.
- Copy checks: 19 protocol, 6 schema, 3 PlantUML, 1 SVG, 12 fixture pairs, both
  regression copies, and the validator semantic-rules copy are byte-identical.
- Post-directive local-board audit: `TASK-260715-2kchi0` has 32 declared and 32
  present resources; `TASK-260721-2ohf99` has 16 declared and 16 present. There
  are no orphaned or missing payloads. The sole empty file is the declared,
  system-managed current-run spawn log; every authored resource is nonempty.
- PlantUML 1.2026.6 `-checkonly`, SVG XML parse, warning/error/deprecation scan,
  and original-resolution visual inspection: pass.
- All 57 protocol task references resolve; `TASK-260717-l639qp` retains the
  corrected exact title.
- `task-board validate`, story plan, `git diff --check`, focused privacy/secret
  scan, and no-dependency-mutation audit: pass. The previously logged broad
  related-plan cycle remains outside this bounded rework.
- `swift test`: 332 tests in 29 suites pass. The existing linker alignment
  warning is unchanged.

Production DNS authorization remains false behind the accepted selected-SSH,
residual-budget, physical-provider, and independent-review gates. The
production-positive JSON remains only a schema contract fixture.
