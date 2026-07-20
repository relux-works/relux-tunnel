# TASK-260715-1vv52g implementation evidence

## Outcome

- Added the checksum-locked `HevSocks5Tunnel` static XCFramework as the native adapter's SwiftPM binary target.
- Added the real `DescriptorBorrowConsumer`: one process-wide HEV lease, one dedicated pthread, public `main_from_str`/`quit`/`stats` calls, join-before-return, and no descriptor close/duplication.
- Added caller-owned MTU, task stack, TCP buffer, UDP-copy-buffer count, maximum-session, pending-authentication, and authentication-timeout inputs.
- Generated exact ADR-020 YAML: MTU 1500 in tests, `udp: tcp`, task stack 24576, TCP buffer 4096, `udp-copy-buffer-nums: 2`, and maximum sessions 1200. Inputs that pinned HEV would silently raise are rejected.
- Added an IPv4-loopback SOCKS boundary with fresh per-run RFC 1929 credentials. Unauthenticated external ingress is closed before the injectable owned-channel adapter seam.
- Added startup-failure cleanup, idempotent stop/join, HEV traffic/config metrics, privacy-safe lifecycle logs, and byte-exact embedded HEV/core/task-system/lwIP notices generated from the pinned manifest.
- Added artifact locks and a stripped-link audit requiring `hev_socks5_tunnel_main_from_str`, `hev_socks5_tunnel_quit`, and `hev_socks5_tunnel_stats`.

## Verification

- `./scripts/native-dependency-tool.py verify --dependency hev-lwip --source-dir .temp/TASK-260715-uopycx/hev-socks5-tunnel` — pass; root and all submodule revisions/hashes, artifact lock, and embedded notices verified.
- `swift-format lint --strict --recursive Sources Tests Package.swift` — pass.
- `swift test` — 47 tests in 7 suites pass.
- `swift build` — pass.
- `swift test --sanitize=thread --filter 'ReluxTunnelNativeAdapterTests.HEVIntegrationTests'` — 6 tests pass, no Thread Sanitizer reports.
- `make validate-native` — pass: reproducibility/negative packaging tests, iOS device, iOS Simulator, macOS provider/shared consumer/harness builds, stripped harness symbol/path/dynamic-link audit, full tests, and final build.

The linker emits the unchanged upstream archive's existing `__DATA,__common` alignment-reduction warning; all artifact, extension-safety, dynamic-link, absolute-path, test, and build gates pass.
