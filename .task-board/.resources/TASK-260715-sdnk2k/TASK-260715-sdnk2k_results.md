# TASK-260715-sdnk2k implementation evidence

## Delivered

- Added a candidate-neutral local nonblocking stream/readiness contract in Core.
- Added two independent structured pumps over the accepted SSHByteChannel seam.
- Each direction owns exactly one current Data value plus an offset and cannot read another chunk until it drains.
- All chunk, SSH write-call, aggregate reservation, fairness operation/byte, and readiness no-progress limits are caller-injected and validated.
- A shared atomic non-waiting BytePumpBufferBudget caps concurrent pump-owned bytes and records peak, reservation, denial, release, and violation baselines.
- Cancellation wakes local readiness, cancels both children, calls channel cancel once, discards late completions, joins children, and releases the reservation once.
- Typed finite terminal events cover EOF, cancellation, local/remote closure, read/write error, zero progress, and bound violation without choosing lifecycle or half-close policy.
- Diagnostics expose only direction, finite operation/pressure/yield/terminal tokens, byte counts, and bounded gauges.

## Fixed memory evidence

Canonical test configuration reserves localReadChunkBytes 257 plus remoteReadChunkBytes 193 = 450 bytes per flow. Observed peak shared reservation is exactly 450 and returns to zero with one reservation and one release. Concurrent-capacity coverage uses two 32-byte flows under a 64-byte aggregate ceiling; the third flow is rejected without queuing, peak is 64, and both accepted reservations release once. One hundred cancelled runs report 100 reservations, 100 releases, zero retained bytes, and zero release violations.

## Integrity and pressure evidence

Canonical deterministic bidirectional transfer:
- local to SSH: 32771 bytes, SHA-256 6d440a591a2318f6333d6ce2c1cfeb68250f0818c3b55f43554633fe0d98f5ad
- SSH to local: 29003 bytes, SHA-256 66f02f2a49b66e79a933ae6b0be4f3719c09c0c8e72d9b91189ca11389414378

The suite also runs twelve changing deterministic seeds with fragmented reads, partial writes, alternating would-block readiness, exact byte/hash equality, SSH-credit suspension, fairness gating, all five suspending cancellation seams, a late positive completion, finite typed failures, zero progress, oversize returns, and a no-spin permanently pressured peer.

## Verification

- swift test --filter BoundedFullDuplexBytePumpTests: PASS, 12 tests
- swift test --sanitize=thread --filter BoundedFullDuplexBytePumpTests: PASS, 12 tests, no TSan report
- repeated seeded integrity test x20: PASS
- swift format lint --strict --recursive Sources Tests Package.swift: PASS
- make validate-core: PASS on rerun, 288 tests in 26 suites plus swift build
- git diff --check and untracked trailing-whitespace scan: PASS
- Core candidate/privacy prohibition scan: PASS
- task-board validate: PASS
- spawn directive checkpoint: no directives

The first full Core run had one unrelated concurrent ProviderAdapterContractTests iOS assertion observe cancellation code 1009 instead of startup-failure code 1007. The exact test passed in isolation, and the full 288-test validation passed on rerun without pump changes. This anomaly is recorded in LOGBOOK.md with the pump decisions and evidence.
