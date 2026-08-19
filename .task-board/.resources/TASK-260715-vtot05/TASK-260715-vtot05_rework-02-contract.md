# TASK-260715-vtot05 rework 02 contract

Remediate the sole material finding in `TASK-260715-vtot05_independent-rereview-02-results.md`. Preserve all independently confirmed provenance, SPDX, URL, linkage, determinism, notice, and boundary behavior.

## Runtime gate requirements

- Do not merely append an ad-hoc regex list. Make traversal/classification fail closed: every regular file under each immutable runtime root must be either a recognized scanned source kind or an exact, documented non-runtime/test/generated exclusion. Reject unknown/new code-like extensions and unclassified entries. Include project-relevant C/C++ variants `.cxx`, `.hpp`, `.hh`, and `.hxx`.
- Reject the eleven reproduced surfaces for the correct reason:
  - Swift Foundation `String(contentsOf:)` remote/ambiguous loading;
  - Objective-C/Foundation `NSData` URL-loading selectors;
  - C/C++ libcurl use;
  - C-family `system`, `popen`, `posix_spawn`, and exec-family process entry points;
  - Go `net/http`, `os/exec`, and `plugin` imports/calls regardless of aliases or grouped/import formatting;
  - the same content introduced through newly recognized C/C++ source/header extensions.
- Preserve explicit local file reads that are demonstrably local and existing legitimate build/test-only exclusions. Make exclusions structural and exact, not substring-based.
- State the audit claim honestly and explicitly: it verifies the complete classified repository runtime surface against forbidden executable-fetch/download mechanisms; it is not a general semantic proof for arbitrary future languages. Any new unclassified file/language must fail until reviewed and classified.
- Add a regression for every reviewer reproduction plus unknown extension/unclassified-file, alias/grouped Go imports, whitespace/comment variations where relevant, and safe local controls.
- Re-run adversarial tests, audit, manifest linkage tests, Go tests/vet, unsigned Swift build, lint/privacy/diff checks, and deterministic double generation.

Do not change board validation rules or perform signing, credentials/Keychain access, app/provider launch, VPN/network mutation, or physical validation.
