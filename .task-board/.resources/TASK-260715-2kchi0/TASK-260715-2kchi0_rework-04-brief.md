# TASK-260715-2kchi0 rework-04 brief

Resolve only the blocking re-review-03 numeric-domain defect while preserving all passing evidence.

Required:
1. Use a true RFC 8785 implementation for the executable regression, or rigorously strengthen the jq-equivalent-domain guard so it rejects every projected number outside the proven jq/JCS-equivalent domain before hashing. At minimum reject unsafe integers outside plus or minus 9007199254740991, negative zero, and every unsupported numeric representation that can diverge from ECMAScript/JCS.
2. Add an executable schema-valid negative control using device.installedMemoryBytes=9007199254740993. It must prove rejection before non-JCS bytes are hashed.
3. Retain the exact positive canonical hash 1872767d6f1a5d920db6f7357b43133114a24c2043011131fba44e4bb96b9abb, runID m3v1-1872767d6f1a5d920db6f735, repetitionID m3v1-1872767d6f1a5d920db6f735-r01, immutable hash 221c543f6dd3cf4a006889afd00ce1a66ea409d1f075dd1c9321852752478fb2, and the trailing-LF rejection.
4. Update fixture expectations and rework results. Propagate the test and every affected validator or protocol resource copy byte-identically. Audit declared resource refs against payloads after all mutations.
5. Rerun focused hash regression, Draft 2020-12 schema fixtures and hostile mutations, copy/ref audit, privacy/logical-reference scans, PlantUML/SVG gates, task-board validate, dependency/diff checks, and swift test.
6. Do not run benchmarks, select tuning winners, authorize production DNS, add tasks or dependency edges, or alter unrelated artifacts.

Evidence source: TASK-260715-2kchi0_re-review-03-verdict-20260722.md.