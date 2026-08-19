# TASK-260715-vtot05 rework 01 contract

Apply the independent reviewer verdict in the attached `TASK-260715-vtot05_results.md`. Preserve the accepted positive implementation and make the audit genuinely fail closed.

## Required fixes

1. Bind every fixed component identity to authoritative evidence, not merely to another mutable generated field:
   - relay source revision/tree/file aggregate and immutable source URL;
   - build-recipe revision/file aggregate and immutable source URL;
   - Go compiler/internal linker archive/version/hash/source;
   - statically linked Go standard library version/hash/license/notice relationship.
   Reject cross-record mismatch even when generated outputs are refreshed.
2. Enforce a strict approved component-to-SPDX/license-text-hash/notice/distribution mapping. Reject false, unsupported, or mismatched license identifiers and text.
3. Make runtime audit scope required, exact, immutable, and non-empty. Do not claim semantic zero-download coverage from a narrow token scan. Cover the actual application/runtime source roots and relevant file kinds, and reject disabled/partial coverage plus representative executable-fetch/download surfaces (`URLSession`, `Data(contentsOf:)`, `NSURLConnection`, process/shell fetch-and-execute patterns, and equivalent project-relevant mechanisms). Preserve legitimate compile-time tooling boundaries explicitly rather than silently skipping them.
4. Parse and strictly validate dependency source URLs against per-component pinned version/revision allowlists. Reject branch/tag/latest/mutable paths, query strings, fragments, placeholders, redirects-by-name, and unsupported schemes/hosts.
5. Add table-driven negative tests reproducing every reviewer finding and meaningful adjacent bypasses. Ensure each test would fail against the previous implementation.
6. Regenerate inventory/provenance/notices/manifest/Swift outputs and demonstrate byte-identical double generation, focused tests, build/lint, privacy checks, and `git diff --check`.

Do not repair the parent aggregate-status mismatch by weakening board validation or falsifying parent dependencies. Do not perform signing, credential access, provider/app launch, VPN preference mutation, tunnel activation, or host network changes.

Return to review only with exact evidence that all previously accepted adversarial mutations are now rejected.
