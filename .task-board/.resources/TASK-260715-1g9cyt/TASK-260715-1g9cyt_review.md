# TASK-260715-1g9cyt — review verdict: accepted

Reviewer: [reviewer] reviewer (claude), run RUN-260720-e1a046, 2026-07-20.

## Verdict

Accepted → `done`. Implementation matches all five acceptance criteria, fits the
ADR-002/2nfz7w boundary architecture, and every validation gate was rerun
independently by the reviewer and passed.

## Independent verification performed

1. `make validate-native` rerun by reviewer, exit 0
   (`.temp/TASK-260715-1g9cyt/review-validate-native-01.log`):
   - `check-core-boundaries` — Core stays dependency-free; NativeAdapter owns
     the native/core boundary; adapters/harness-support pinned to exactly
     {Core, NativeAdapter}.
   - fixture source-hash + per-file artifact-lock verify; byte-identical
     deterministic rebuild (`cmp` of committed vs rebuilt lock JSON); committed
     notices match regeneration.
   - negative gates all fail closed: tampered source, missing x86_64 slice,
     dylib substituted for the static archive, embedded absolute build path,
     artifact hash drift.
   - Apple matrix (Xcode 26.5, Release, `APPLICATION_EXTENSION_API_ONLY=YES`,
     `CODE_SIGNING_ALLOWED=NO`): NativeAdapter for iOS device / iOS Simulator /
     universal macOS, both provider adapters, macOS harness; stripped SwiftPM
     release harness passed `inspect-linked` (system-only dylibs, host arch,
     no absolute checkout path, no dlopen-family symbols).
   - `swift test`: 41 tests in 6 suites passed; final `swift build` passed.
2. Reviewer re-inspected the implementer-rebuilt HEV artifact:
   `./scripts/native-dependency-tool.py inspect --dependency hev-lwip
   --xcframework .temp/TASK-260715-1g9cyt/HevSocks5Tunnel.xcframework` →
   "static and extension-safe".
3. Evidence integrity: SHA-256 of `TASK-260715-1g9cyt_validation.log`,
   `TASK-260715-1g9cyt_hev-rebuild.log`, and
   `TASK-260715-1g9cyt_HEV_THIRD_PARTY_NOTICES.txt` recomputed and match the
   values claimed in `TASK-260715-1g9cyt_results.md`.
4. Manifest HEV pins cross-checked against the TASK-260715-uopycx audit:
   root `ad760049`, core `c234519`, task-system `b1afa0e`, lwIP `2a11c14`,
   yaml `efa3611` — exact match.
5. Strict `swift format lint`, `python3 -m py_compile`, `sh -n` on all three
   shell scripts, and manifest JSON parse rerun clean.

## AC mapping

- AC1 (fixture builds/links everywhere): Apple matrix + SwiftPM harness link,
  reviewer rerun. PASS.
- AC2 (archive inspection rejects dylib/abs-path/missing-arch/unsafe deps):
  `inspect_xcframework` + `inspect-linked` positive runs plus five negative
  tests. PASS.
- AC3 (machine-readable inputs): `NativeDependencies/manifest.json` carries
  revision, source SHA-256, flags, triples, slices, licenses, notices output,
  rebuild/verify commands, cache policy, per-file artifact lock. PASS.
- AC4 (deterministic artifacts, reviewable diff): byte-identical rebuild gate
  plus CONTRIBUTING rule banning unpinned/opaque binary updates. PASS.
- AC5 (HEV + both SSH candidates plug in without target-graph redesign):
  docs/native-dependency-packaging.md target graph and checklist;
  hev-lwip manifest entry exercised end-to-end (clean-source verify →
  upstream build-apple.sh → inspection → notices). ADR-014 SSH choice
  correctly left open. PASS.

## Non-blocking observations

- HEV manifest slice minimums (iOS 15.0 / macOS 10.14) mirror the pinned
  upstream build-apple.sh, not project minimums (iOS 18 / macOS 15); linking a
  lower-minimum static archive into higher-minimum consumers is safe, and the
  1vv52g integration keeps its own platform floor.
- `ABSOLUTE_BUILD_PATH` is a heuristic over /Users, /tmp, /private/{tmp,var};
  it covers the path classes local and CI builds actually produce.
- Determinism is proven per Xcode build (17F42); the cache policy correctly
  keys on `xcode_build` so a toolchain bump forces a reviewed re-lock.
