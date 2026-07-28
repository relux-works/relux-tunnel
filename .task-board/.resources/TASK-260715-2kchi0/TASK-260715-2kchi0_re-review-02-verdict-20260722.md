# TASK-260715-2kchi0 re-review-02 verdict

Date: 2026-07-22
Role: independent reviewer
Verdict: changes requested
Route: analysis

## Verdict

Rework-02 closes the stable-group, closed comparison-result, exact m=3,
production-authority, status-reason, and simultaneous-latency findings from
re-review-01. The task is not accepted because the advertised positive fixture
does not satisfy the protocol's own RFC 8785 identity and immutable-manifest
rules. The downstream semantic validator is explicitly required to reject it.

## Blocking finding: fixture hashes include a non-JCS trailing newline

Protocol sections 2 and 10.1 require SHA-256 over the RFC 8785 JCS UTF-8 bytes
of the exact row projection and the complete row with only
`review.immutableManifestSHA256` removed. RFC 8785 serialization has no trailing
record separator. The fixture values were produced with `jq -cS`, whose output
ends in byte `0a`; `jq -cjS` emits the same canonical JSON without that extra
byte.

Independent recomputation from
`.research/fixtures/TASK-260715-2kchi0_valid-pass.json` proves the mismatch:

```text
recorded canonical: 389a19b5e967ac58d68c5eacb0054641975065de42853440c18fbe4ffc13a84a
RFC-8785 bytes:      1872767d6f1a5d920db6f7357b43133114a24c2043011131fba44e4bb96b9abb

recorded immutable: 270f89cfc8eb4f10d62b048d0b90ca6f8b1d7fd07489da9e50dc05306385f65c
current-row JCS:     0b1475324247ea483ff094fdbfb27304321f5ab0de97907e6ef632e03d6a551f
```

After correcting the canonical hash and its derived identifiers, the fixture
must use:

```text
runID:        m3v1-1872767d6f1a5d920db6f735
repetitionID: m3v1-1872767d6f1a5d920db6f735-r01
immutable:    221c543f6dd3cf4a006889afd00ce1a66ea409d1f075dd1c9321852752478fb2
```

The producer's tracked log confirms the source of the recorded values: lines
42098 and 44884 of
`.temp/spawn-runs/RUN-260721-f38782/runner.log` pipe `jq -cS` directly into
`shasum`. The rework-02 result then reports those newline-inclusive hashes as
recomputed and equal.

This is blocking because protocol semantic rules 1 and 9 require the future
`TASK-260721-2ohf99` validator to reject hash-mismatched inputs. Every positive
overlay inherits the invalid base identity and immutable hash, so the fixture
set cannot serve as a positive end-to-end semantic regression input as written.

## Required rework

1. Recompute the canonical row bytes with an RFC 8785 implementation or an
   exactly equivalent no-trailing-data serialization; update
   `canonicalRowConfigSHA256`, `runID`, and `repetitionID`.
2. Recompute `immutableManifestSHA256` after those identity corrections, then
   update affected expectations/results and both task resource copies.
3. Add an executable regression check that hashes only the JCS bytes (and
   rejects trailing LF/whitespace), and ensure the positive fixture is accepted
   by the protocol's semantic hash rules while a newline-inclusive mutation is
   rejected.
4. Propagate revised protocol-task and validator-task fixture copies
   byte-identically and rerun the existing schema, copy, privacy, diagram,
   board, diff, and Swift gates.

## Passing evidence retained

- Draft 2020-12 metaschema passes. Valid, equality, multi-repetition, m=3, and
  production compositions validate; one-over rejects exactly at 8,388,609
  bytes; hostile, missing-review/statistics, unavailable-measured-pass, and
  invalid-environment-measured-pass compositions reject for the intended
  schema constraints.
- Additional production-hostile mutations reject false safety/statistics and
  privacy-scan gates, blockers, provisional authority, unavailable
  reviewer/time/classification, unavailable metric results, red comparison
  safety, empty lineage, missing group, zero candidate count, absolute paths,
  illegal status, and capture-required unauthorized artifacts.
- The comparison schema is closed over all sixteen required metric families;
  the closed parameter-family and injectable parameter-name projections are
  present. Three paired repetitions share one comparison group. Exact m=3
  arithmetic independently evaluates to `59/60` with ranks `83/9916`.
- TTFB, DNS, RTT, outage, and failure latency rows simultaneously contain
  fixed-unit median/p95/p99/sample-count/raw-reference fields or one explicit
  unavailable object.
- The protocol retains exact SplitMix64 impairment/bootstrap streams, integer
  effect and quantile rules, multiplicity/classification boundaries,
  unavailable/red preservation, macOS-first/iPhone-deferred scope,
  selected-SSH DNS startup/open/reuse/retire rows, and injectable numeric/policy
  gates. No benchmark, winner, or production DNS authorization is claimed.
- Nineteen protocol, six schema, three PlantUML, one SVG, and both copies of
  every fixture are byte-identical to their sources.
- PlantUML 1.2026.6 `-checkonly`, SVG XML parse, warning/error/deprecation scan,
  and visual inspection pass; the render is readable and warning-free.
- All 57 concrete task references resolve; `TASK-260717-l639qp` has the exact
  corrected title. `task-board validate`, story planning, `git diff --check`,
  dependency-edge diff, and focused privacy scans pass. The known broad related
  plan cycle is pre-existing and does not include this protocol task or its new
  validator task.
- `swift test` passes 332 tests in 29 suites; only the previously recorded
  linker alignment warning remains.

No implementation code was modified during this review.
