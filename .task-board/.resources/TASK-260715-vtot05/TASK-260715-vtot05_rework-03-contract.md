# TASK-260715-vtot05 rework 03 contract

Remediate the sole AC5 finding in `TASK-260715-vtot05_results.md` from independent re-review 03. Preserve all already verified provenance/license/URL/linkage/notices/boundary behavior.

## Required implementation

- Replace direct-call-shaped matching with a fail-closed per-language lexical/token normalization stage for the enumerated forbidden mechanisms.
- For C/Objective-C/C++:
  - normalize escaped newlines and comments before analysis;
  - detect forbidden symbol references, address-taking, macro aliases, and token-pasting/split-token forms for libcurl, `system`, `popen`, `posix_spawn*`, and exec-family APIs, not only calls;
  - reject dynamic selector/reflection paths capable of constructing or invoking Foundation URL-loading selectors (`NSSelectorFromString`, `performSelector`, and equivalent project-relevant forms).
- For Swift:
  - detect `Process` type references/aliases/construction, not only `Process()`;
  - detect `Data`/`String` remote or ambiguous `contentsOf` initializers including `.init` references assigned to variables;
  - preserve only structurally explicit `URL(fileURLWithPath:)` local-read forms.
- For Go, retain alias-independent import rejection and ensure grouped, dot, blank, raw-string, and comment/whitespace variants remain covered.
- Add executable regression fixtures for every compiler-valid reproduction in re-review 03: C macro alias, escaped-line identifier, function pointer, token-pasted libcurl, Swift Process typealias, Swift Data initializer reference, and Objective-C split dynamic selector. Where local compilers are available, typecheck/preprocess the fixtures before asserting scanner rejection so tests prove they are real language forms.
- Keep complete fail-closed file classification and the explicitly bounded documentation claim. Avoid adding a universal semantic-proof claim.
- Run all prior adversarial regressions and the full focused/build/lint/determinism/privacy gates.

Do not change board validation rules and do not sign, access credentials/Keychain, launch app/provider, mutate VPN/network state, or perform physical validation.
