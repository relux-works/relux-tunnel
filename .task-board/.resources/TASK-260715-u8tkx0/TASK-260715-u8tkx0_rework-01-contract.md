# Rework 01 contract — TASK-260715-u8tkx0

The fresh reviewer requested changes. Read the attached reviewer outcome `TASK-260715-u8tkx0_reviewer-results.md` and treat its commands/evidence as authoritative reproduction input.

Required corrections:

1. Fix the strict update procedure so a second operator actually reproduces the full accepted release tree, not only the four binaries/archive. The reviewer observed nondeterministic Syft `documentNamespace` UUID and `creationInfo.created` drift in all four raw SPDX files, cascading into manifests/checksums. Use the accepted deterministic normalization/build path from current repository evidence, or explicitly retain immutable historical metadata where reproduction is not claimed; never claim raw historical Syft output is reproducible.
2. Fix the cross-clone comparator procedure so all compared paths satisfy its path-containment contract. The documented command must execute successfully from the documented directory.
3. Add complete copy-paste commands for exact 15-artifact comparison, native Darwin arm64 17-check smoke, mismatch red path, unsupported-runtime red path, and two independent trusted application-manifest regenerations/comparisons.
4. State unambiguously where `relux-relay-manifest-v1.json` (release-builder manifest) versus `relux-relay-assets-v1.json` (trusted application manifest) is generated, checked, retained, bundled, or rolled back.
5. Record the full-release metadata anomaly and its resolution in the producer outcome and LOGBOOK. Preserve the already verified split source/recipe pin warning, strict update order, RACI, rollback/incident semantics, M2/M5 boundary, live task IDs, and build-only safety.
6. Re-run the entire documented procedure from a fresh task-scoped root. Attach exact exits/hashes and update the task outcome. Do not commit or push, and do not install/start/configure a VPN or alter system networking.

Return to `to-review` only when every reviewer finding is closed with executable evidence.
