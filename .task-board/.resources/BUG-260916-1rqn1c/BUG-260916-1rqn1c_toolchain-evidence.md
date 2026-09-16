# BUG-260916-1rqn1c toolchain evidence (official sources)

Fetched 2026-09-16. All URLs are `actions/runner-images @ main` unless noted.

## 1. Hosted failure (primary source)

- PR: relux-works/relux-tunnel#6
  (`delivery/STORY-260715-1y04r0-rev3`, head
  `d45c85d67b78b6578b5cb0821bd2e78217124d30`, OPEN).
- Run: 35091586150 (`gh run view 35091586150 --repo relux-works/relux-tunnel`).
- Failed job: `generated project credential-free validation`
  (ID 104778924295), step `Run the local credential-free gate`.
- Observed stage order: relay-tool-bootstrap PASS, relay-packaging PASS,
  validation-contract-tests PASS, deterministic-generation PASS,
  macos-target-builds-and-contracts PASS, core-boundaries PASS,
  swift-testing PASS, swift-release-build PASS, native-packaging FAIL
  (exit 2).
- Failing command and output (from `--log-failed`):
  `make check-native-dependencies` ->
  `python3 scripts/libssh2-fork-tool.py verify` ->
  `libssh2-fork-tool: Xcode build mismatch: expected Build version 17F42,
  got Xcode 16.4 / Build version 16F6`.

## 2. Runner label table (official, README.md)

| Image | Arch | YAML labels |
| macOS 26 | x64 | `macos-latest-large`, `macos-26-intel`, `macos-26-large` |
| macOS 26 Arm64 | arm64 | `macos-latest`, `macos-26`, `macos-26-xlarge` |
| macOS 15 | x64 | `macos-15-large`, `macos-15-intel` |
| macOS 15 Arm64 | arm64 | `macos-15`, `macos-15-xlarge` |

`macos-26` is the arm64 image: same architecture as `macos-15`, so the
existing arm64 Mise checksum pairing in ci.yml is preserved. `macos-latest`
already points at macOS 26 Arm64 (GA).

## 3. Xcode inventory, macos-15-arm64 (cannot host the pin)

Source: `images/macos/macos-15-arm64-Readme.md` (identical Xcode table in
`macos-15-Readme.md`).

| Version | Build | Path |
| 26.3 | 17C529 | /Applications/Xcode_26.3.app |
| 26.2 | 17C52 | /Applications/Xcode_26.2.app |
| 26.1.1 | 17B100 | /Applications/Xcode_26.1.1.app |
| 26.0.1 | 17A400 | /Applications/Xcode_26.0.1.app |
| 16.4 (default) | 16F6 | /Applications/Xcode_16.4.app |
| 16.3 | 16E140 | /Applications/Xcode_16.3.app |
| 16.2 | 16C5032a | /Applications/Xcode_16.2.app |
| 16.1 | 16B40 | /Applications/Xcode_16.1.app |
| 16.0 | 16A242d | /Applications/Xcode_16.app |

Newest available: 26.3 (17C529). Pinned 17F42 absent. Default 16F6 matches
the hosted failure exactly.

## 4. Xcode inventory, macos-26-arm64 (hosts the pin)

Source: `images/macos/macos-26-arm64-Readme.md` (identical Xcode table in
`macos-26-Readme.md`). Image Version: 20260907.0351.1, macOS 26.6.2.

| Version | Build | Path |
| 26.6 (default) | 17F113 | /Applications/Xcode_26.6.app |
| 26.5 | 17F42 | /Applications/Xcode_26.5.app |
| 26.4.1 | 17E202 | /Applications/Xcode_26.4.1.app |
| 26.3 | 17C529 | /Applications/Xcode_26.3.app |
| 26.2 | 17C52 | /Applications/Xcode_26.2.app |
| 26.1.1 | 17B100 | /Applications/Xcode_26.1.1.app |
| 26.0.1 | 17A400 | /Applications/Xcode_26.0.1.app |

Pinned 17F42 present at `/Applications/Xcode_26.5.app`, but the image
default is 26.6 (17F113): the workflow must select explicitly, not just
move images. Installed SDKs include macOS/iOS/tvOS/watchOS 26.5 under
Xcode 26.5/26.6; deployment minimums (macOS 15.0, iOS 18.0) are
compiler-supported as proven by artifact provenance (built with 17F42).

## 5. Repository pin sources (unchanged by this fix)

- `NativeDependencies/manifest.json`:
  `dependencies.libssh2-openssl.compiler.xcode_build = "17F42"`,
  `dependencies.hev-lwip.rebuild.xcode_build = "17F42"`.
- `Probes/macOSPacketTunnelProbe/README.md`: recorded baseline is
  Xcode 26.5 (`17F42`).
- Enforcement: `verify_xcode_build` in `scripts/libssh2-fork-tool.py`
  (runs `xcodebuild -version`, requires `Build version 17F42`).

## 6. Local toolchain strings (validation context)

- `xcodebuild -version`: Xcode 26.5, Build version 17F42 (selected).
- `xcode-select -p`: `/Applications/Xcode_26_5.app/Contents/Developer`
  (note underscores: local install naming differs from hosted runners).
- Also installed: `Xcode_26_6.app` (Xcode 26.6, build 17F113 — same
  build as the macos-26 hosted default; used for the negative proof via
  `DEVELOPER_DIR` override, exit 1, no system mutation).
- `swift --version`: Apple Swift 6.3.2, target arm64-apple-macosx28.0.
- Host: macOS 27.0 (26A428).
