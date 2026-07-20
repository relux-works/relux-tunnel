# BUG-260720-2zh86a review — ACCEPTED

Reviewer independently re-verified every acceptance criterion. Verdict: accepted → done.

## AC verification

**AC1 — deployment minimums.** Verified via `otool -l` on every slice of both committed
XCFrameworks. HEV: ios-arm64 minos 18.0 (platform 2), ios-arm64_x86_64-simulator 18.0 both
arches (platform 7), macos-arm64_x86_64 15.0 both arches (platform 1), tvos-arm64 18.0
(platform 3), tvos-arm64_x86_64-simulator 18.0 both arches (platform 8). ReluxLibSSH2:
ios 18.0, ios-simulator 18.0 both arches, macos 15.0 both arches. No slice advertises
10.14/11.0. Matches Package.swift (`.iOS(.v18)`, `.macOS(.v15)`) / ADR-016. Additionally,
`inspect_xcframework` now enforces exact `minos == manifest minimum` per slice AND rejects
unmodeled slices, so AC1 is a standing gate, not a snapshot.

**AC2 — full matrix.** Reviewer ran `make validate-native` independently: exit 0
(.temp/BUG-260720-2zh86a/review-validate-native-01.log). Full matrix built: NativeAdapter
iOS device/simulator/macOS, IOSAdapter iOS device/simulator, MacOSAdapter macOS, Harness
macOS + SwiftPM release link audit ("linked dependencies and architectures are valid"),
110 Swift tests in 12 suites passed, `swift build` clean. No deployment-target stop.

**AC3 — vendor-path-only fix.** `build_hev` (scripts/native-dependency-tool.py:613) reads
`build-apple.sh` from the pinned checkout only AFTER `verify_hev_source` enforces exact
revision, clean tree, and git-archive SHA-256; the script is rendered in memory
(`render_hev_build_script`) and piped to bash via stdin — the pinned checkout and C sources
are never modified. Regex verified against the real upstream script: matches exactly the 8
`buildStatic` invocation lines, skips the comment on line 8 and the function definition on
line 9. Fail-closed design: unknown SDK → error, unmodeled platform → error, SDK-coverage
mismatch → error, inconsistent per-platform minimums → error; and even a hypothetically
missed line would be caught downstream by the exact-minos-set inspection. ReluxLibSSH2 fixed
via manifest target triples + explicit minimum flags (18.0/15.0).

**AC4 — gates green, no regressions.** Reviewer ran independently: `make validate-core`
exit 0; `make validate-libssh2` exit 0 with the real sshd rekey/KEX/global-request
integration passing ("client rekey completed…; 14 server-KEX transitions observed").
Static/extension-safety + checksum (`--verify-lock`) inspections of both committed
artifacts pass inside validate-native. New negative gate (unexpected-slice fixture) and 4
new unit tests for the render logic pass. py_compile, bash -n, manifest JSON parse,
`git diff --check` all clean.

**AC5 — reproducibility.** `ZERO_AR_DATE=1` + stable locale in the build seam eliminate the
libtool timestamp nondeterminism (documented as anomaly in LOGBOOK). Implementer's clean
rebuild log shows the rebuild reproducing the locked hashes; the artifact lock verification
against the committed artifacts passed again in the reviewer's run.

## Quality notes (non-blocking)

- The render seam models all retained slices (incl. tvOS at 18.0) instead of silently
  passing unknown ones through — good fail-closed posture.
- New minos + unexpected-slice enforcement in the inspector turns this whole bug class into
  a permanent gate.
- `test_hev_build_uses_deterministic_archive_environment` merely restates a constant dict —
  low value, harmless.
- Docs (docs/native-dependency-packaging.md) and LOGBOOK updated accurately, including root
  cause (upstream hardcoded 15.0/10.14/17.0 minimums; mixed 10.14/11.0 macOS records).

## Reviewer evidence

- .temp/BUG-260720-2zh86a/review-validate-native-01.log (exit 0)
- .temp/BUG-260720-2zh86a/review-validate-core-01.log (exit 0)
- .temp/BUG-260720-2zh86a/review-validate-libssh2-01.log (exit 0)
