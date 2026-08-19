# TASK-260715-vtot05 rework 04 contract

Remediate both material findings in the independent re-review 04 `TASK-260715-vtot05_results.md`. Preserve all previously verified AC1-AC4 and AC5 regressions.

## Language-specific lexical fixes

- Split comment/literal handling by language. C/C++/Objective-C and Go block comments are non-nesting: the first `*/` returns to code. Preserve Swift's language-appropriate comment/raw-string behavior separately.
- Normalize C/C++ alternative preprocessing tokens, including `%:%:` as token paste, before reconstructing forbidden symbol references.
- Tokenize Swift escaped identifiers (backticks) as identifiers, not Go raw strings.
- Parse Swift raw-string interpolation (`#"...\#(...)..."#` and supported pound counts) and inspect interpolation code for forbidden surfaces.
- Reject typed/inferred ambiguous Swift `.init(contentsOf:)` references unless the argument is structurally the approved explicit `URL(fileURLWithPath:)` local form. Preserve safe local `Data`/`String` controls.
- Add compiler-backed regressions for all six reviewer fixtures: C non-nesting-comment `system`, C `%:%:` token paste, Swift inferred `Data .init(contentsOf:)`, Swift raw interpolation `Process`, Swift escaped `Process`, and Go non-nesting-comment aliased `net/http`.
- Add adjacent safe/comment/raw-string controls so the lexer does not turn documentation-only text into false positives.

## CI history fix

- Ensure the exact workflow job running `relay-supply-chain-audit` checks out enough Git history to resolve both pinned provenance commits (`fetch-depth: 0` is acceptable).
- Add a static/workflow regression proving the history requirement is declared, and reproduce the audit from a fresh checkout shape representative of CI without any network fetch during the task.

Run the full adversarial suite, audit, manifest/linkage tests, Go tests/vet, unsigned Swift build, Actionlint/format/privacy/diff checks, deterministic double generation, and board validation. Do not weaken validation.

No signing, credentials/Keychain access, provider/app launch, VPN/network mutation, or physical validation.
