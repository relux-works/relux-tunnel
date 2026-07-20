# TASK-260715-lovbdz reviewer verdict — rework 02

Date: 2026-07-21
Role: reviewer
Verdict: ACCEPTED

## Rework verification

The rework-02 encoded-size fixture closes the remaining acceptance blocker. It builds diagnostics snapshots from 1,500 and 2,000 unique metric names that all satisfy the documented metric-name token and 64-byte validation. The fitting model is independently encoded with the same deterministic sorted-key JSON settings and then succeeds through `RuntimeMessageCodec`. The oversized model is independently measured above 64 KiB and `RuntimeMessageCodec.encode` is asserted to throw the exact `payloadTooLarge(maximumBytes:actualBytes:)` value with the diagnostics limit and measured byte count. The test therefore reaches the encoder's payload-size guard rather than an earlier model-validation error.

## Acceptance evidence

- AC1: `RuntimeMessages.md` documents every wire family, current version, maximum size, required fields, and defaults. Per-model constants and bounded codecs implement deterministic unsupported protocol/schema/kind/value and corrupt-input errors. Nested configuration-reference schema validation is present.
- AC2: Provider/start/runtime configuration uses distinct UUID-backed profile, profile-revision, credential, and trust references. The shared `TunnelConfiguration` string-parameter escape hatch is removed. Security tests reject secret-shaped reference values and prove no private-key/passphrase field is representable.
- AC3: Capability and lifecycle snapshots carry independent TCP, safe-DNS, UDP, route-mode, route-installed, and health facts without a full-mode field. Unknown route mode, lifecycle state, or route state projects all capability facts false.
- AC4: Deterministic round-trip/golden, unknown-field, corrupt UTF-8/JSON/number/depth/duplicate/trailing, missing-field, old/future version, provider-input, decoded-oversize, and exact encoded-oversize tests pass. Diagnostics absent aggregates default empty while explicit null remains corrupt.
- AC5: Core boundary validation finds no platform or selected-engine imports in shared contracts. Explicit builds pass for `ReluxTunnelCore`, `ReluxTunnelIOSAdapter`, `ReluxTunnelMacOSAdapter`, `ReluxTunnelHarnessSupport`, and `ReluxTunnelHarness`; the package tests exercise both provider roots.

## Independent validation

- Focused runtime codecs: 15 tests in 2 suites passed.
- `make validate-core`: core boundary checks, native dependency verification, 183 tests in 21 suites, and post-test `swift build` passed.
- `swift-format lint --strict --recursive Sources Tests Package.swift`: passed with no diagnostics.
- `git diff --check`: passed.
- `task-board validate`: passed.
- Explicit shared/core/adapter/harness target builds: passed.

No acceptance-blocking finding or stop-the-line boundary remains.
