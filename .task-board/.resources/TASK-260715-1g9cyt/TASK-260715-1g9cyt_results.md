# TASK-260715-1g9cyt — extension-safe native packaging results

## Decision and implementation

- ADR-019 selects source-rebuilt static XCFramework SwiftPM `binaryTarget`s for
  custom-build C graphs (HEV/lwIP and a possible libssh2 adapter), while a
  possible ReluxNIOSSH fork remains a pinned SwiftPM source dependency.
- `ReluxTunnelNativeAdapter` is the named native/Core boundary. Providers and
  harness support depend on it; `ReluxTunnelCore` remains dependency-free.
- The harmless `CReluxNativeFixture` XCFramework is checked in with source,
  module map, public header, MIT license, deterministic rebuild command, and a
  per-file SHA-256 lock. Its source bundle hash is
  `7b60fe3e2c3be07eea15cfcb331474318d950315e73c2a423bc6ff0e297b015d`.
- `NativeDependencies/manifest.json` records revision/source hashes, compiler
  flags, target triples, slices, static/extension-only policy, license inputs,
  rebuild commands, HEV root/submodule pins, and cache policy.

## Fail-closed and linkage evidence

- Fixture rebuilds are byte-identical to the checked-in artifact.
- Negative tests reject tampered source, artifact-hash drift, a missing
  architecture, a dylib substitution, and an embedded absolute build path.
- XCFramework inspection rejects non-static libraries, dynamic-loader symbols,
  unsafe dylib/rpath load commands, missing module maps, architecture drift,
  absolute build paths, and artifact hash drift.
- The pinned HEV checkout and all four submodules verified clean at their exact
  revisions/archive SHA-256 values before the complete upstream Apple build.
  The rebuilt HEV XCFramework passed static linkage, module map, iOS device,
  iOS simulator, universal macOS, extension-safety, and absolute-path checks.
- The linked production SwiftPM harness contains the fixture symbols, only
  Apple system dynamic dependencies, the host architecture, and no absolute
  checkout path after release stripping.

## Validation

`make validate-native` passed on Xcode 26.5 (17F42):

- strict Swift format lint, Python compilation, POSIX shell syntax, and JSON
  validation;
- boundary guard and manifest/source/artifact verification;
- deterministic rebuild plus negative archive/linkage tests;
- Release Xcode builds with `APPLICATION_EXTENSION_API_ONLY=YES` for iOS device,
  iOS Simulator, universal macOS native consumer, both provider adapters, and
  the universal macOS harness;
- production SwiftPM harness link/archive inspection;
- `swift test`: 41 tests in 6 suites passed;
- final `swift build` passed.

Evidence SHA-256:

- validation log: `1ac08669cbe5750d1e79e4b84c1e3988e229aa3aebff6e5694694084dcd249a7`
- HEV rebuild log: `fd83fca534c9980b422512c5d1ed1b666ff45586a2b883ca659d4650aa78f87f`
- generated HEV notices: `8383d7e736b9affe38ad2dd1c1106bf0ca4a6b84ea3ba6705704c302d2fb77d4`

## Integration handoff

`docs/native-dependency-packaging.md` gives unchanged graph placements and
checklists for `ReluxTunnelHEVAdapter`, `ReluxTunnelLibSSH2Adapter`, and
`ReluxTunnelNIOSSHAdapter`. Production HEV/runtime behavior and the ADR-014 SSH
engine choice remain outside this task.
