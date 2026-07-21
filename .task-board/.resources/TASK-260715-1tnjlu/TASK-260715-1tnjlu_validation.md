# TASK-260715-1tnjlu validation — rework 01

Date: 2026-07-21  
Result: PASS

## Commands and results

| Check | Result |
| --- | --- |
| `task-board validate` | PASS — board valid, no issues. |
| `task-board q --format compact 'plan(TASK-260715-1tnjlu, mode=related)'` | PASS — related plan generated after linking TASK-260721-3miqh4; no cycle or invalid dependency. |
| Full queries for TASK-260721-3miqh4, TASK-260721-33o8fc, TASK-260721-2raag7, TASK-260715-5o6jqg, TASK-260715-28jdml, and TASK-260715-336ljl | PASS — titles, descriptions/AC, dependency direction, and task-scoped preconditions are present. |
| Stale numeric/DoH scans with `rg` | PASS — prior 5/5/15/10-second, 32/128-query, and one-to-four values occur only in explicit removal history; no source-of-truth or downstream brief treats them as active. Baseline tunneled-DoH wording is removed. |
| Local Markdown link resolution for changed spec/research files | PASS. |
| `git diff --check` | PASS. |
| `dot -Tsvg ...` and `xmllint --noout ...` | PASS. |
| Original-resolution PNG inspection of the rendered DOT | PASS — bootstrap, generation-global endpoint, M1 connection epoch, M2 same-endpoint fallback, coordinated promotion, forbidden physical resolver, and teardown are legible and unclipped. |
| Research/resource, DOT/resource, SVG/resource, and rework-outcome/resource byte comparison | PASS. |
| `make validate-core` | PASS — core boundary/native dependency verification, 306 Swift tests in 27 suites, and post-test `swift build`. |

## Artifact SHA-256

| Artifact pair | SHA-256 |
| --- | --- |
| Research decision and `TASK-260715-1tnjlu_resolver-policy-decision.md` | `48bca1e99a24aa2cb335615960dbb14faa6bce5bb04b5b93fcb52ad67ddfdc2c` |
| DOT source and attached DOT | `d7e57398b7e24e8bc0a74c529a5ee73b3304ea9450110aa22a165ba3e82232d6` |
| SVG render and attached SVG | `ea70b7071b0e3937c3c228bcca927a69244ed27a9d6f8dd3631d927fb1bc2c49` |
| Rework outcome and attached outcome | `1072b7ee39edc0d84e4cbd6d043063d8f256f22061ddcf53c32d5b23ea4a07bd` |

## Review readiness

All three requested-change branches have traceable source-of-truth text,
developer-ready tasks, dependencies, task-scoped resources, and verification.
ADR-022 remains Proposed and TASK-260715-1tnjlu remains a producer handoff; the
independent reviewer owns acceptance. No human vendor/product decision is
required. The subsequent production numeric choice is explicitly owned by
TASK-260721-3miqh4.
