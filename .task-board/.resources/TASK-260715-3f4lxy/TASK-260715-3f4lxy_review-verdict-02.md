# TASK-260715-3f4lxy reviewer verdict 02 — changes requested

## Verdict

Changes requested. Route to `to-dev`. The focused fail-open rework is correct and all implementation gates pass, but the checked-in public Runtime Messages DocC contract contradicts the newly implemented start-request wire format.

## Required correction

`RuntimeStartRequest` is now an exact five-field versioned request with `protocolVersion`, `schemaVersion`, `kind=sshProfileSnapshotStart`, `configurationGeneration`, and `snapshotDigestSHA256` (`Sources/ReluxTunnelCore/RuntimeMessageModels.swift:198-237`, decoder at lines 847-872). However, `Sources/ReluxTunnelCore/ReluxTunnelCore.docc/RuntimeMessages.md:12-20` still says the start request has no command kind and contains only `schemaVersion` plus `configurationReference`; lines 41-42 still claim validation of a nested configuration-reference schema. This is a public contract regression and does not fit the implemented architecture.

Update that DocC page to describe the exact five-field bounded digest request, exact-key rejection behavior, generation/digest validation, and nil-start-option behavior. Keep the rework focused; no loader behavior change is requested by this verdict.

## Independent implementation evidence

- Accepted contract SHA-256 recomputation — exit 0; exact digest `8c81d2dc15904d6648f1333620370ac2c8c455e081fe6e98b4480a92c64bd5f2`.
- Source inspection confirms recursive normalized prohibited-field rejection covers the requested roots/suffixes and nested case/punctuation fixtures.
- Source inspection confirms a present start request compares both generation and SHA-256 of the exact validated stored bytes before first capture; byte-different later candidates fail under the once-only lock.
- `swift test --filter SSHProfileSnapshotLoaderTests` — final invocation exit 0; 13/13 passed. An earlier logging-wrapper invocation ran the same 13 tests successfully but exited 1 afterward because `status` is a read-only zsh parameter; it was corrected and rerun.
- Combined loader/runtime-start/session focused run — exit 0; 52 tests in 4 suites passed.
- Full `swift test` — exit 0; 392 tests in 32 suites passed, including HEV.
- `swift build` — exit 0; existing linker alignment warning only.
- `swift format lint --recursive Sources Tests Package.swift` — exit 0.
- `make check-core-boundaries` — exit 0.
- `git diff --check -- Sources Tests LOGBOOK.md` — exit 0.
- Loader prohibited-API scan — exit 0 and clean.
- Public secret-bearing model-field scan — exit 0 and clean.
- `task-board validate` — process exit 0 and reports the existing aggregate mismatch while this child is in review (`STORY-260715-2wjwuf` stored `to-dev`, aggregate `reviewing`).

## Re-review gate

Verify the DocC start-request contract matches the implemented five-field wire format, then rerun focused tests, full `swift test`, `swift build`, format lint, core-boundary validation, and `git diff --check` with real exit codes.
