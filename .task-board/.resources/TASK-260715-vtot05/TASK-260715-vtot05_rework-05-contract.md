# TASK-260715-vtot05 rework 05 contract

Remediate the single AC5 finding in the latest independent re-review 05 verdict while preserving all verified behavior.

- Refactor C-family token-paste reconstruction into one canonical set of complete/reconstructed identifiers after normalizing both `##` and `%:%:`.
- Apply that reconstructed identifier set to every extension-appropriate forbidden mechanism: C process/exec symbols, libcurl symbols, Foundation network symbols, Objective-C URL-loading selectors, and Objective-C reflection/dynamic-selector symbols.
- Add compiler-backed negative regressions for Objective-C `##` and `%:%:` construction of URL-loading selectors and at least one reflection symbol. Confirm each fixture compiles/preprocesses before scanner rejection.
- Add safe comment/string/token controls to prevent accidental reconstruction from non-code.
- Re-run all prior adversarial tests, audit, manifest/linkage, full-history CI static/local checks, Go tests/vet, unsigned Swift build, lint/privacy/determinism/diff, and board validation.

Keep the documented bounded claim. Do not alter board validation or perform signing, credential access, provider/app launch, VPN/network mutation, or physical validation.
