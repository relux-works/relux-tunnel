# TASK-260715-1i49fm runtime diagnostics implementation evidence

## Implemented schema
- Schema v1 uses a fixed allowlist of 95 monotonic counters, 56 gauges, one cumulative DNS-latency histogram with 12 fixed buckets, and at most one redacted error per each of 10 finite domains.
- Generation-scoped recorders serve TunnelMetrics for packet bridge and HEV plus SSHTransportMetricsSink for lane-neutral SSH updates. Typed APIs cover coordinator transition uptime, component health, TCP flows and bytes, queue-drop reasons, DNS result classes and latency, route mode/install state, memory samples, and redacted errors.
- A newer generation resets counters, gauges, histogram buckets, errors, and snapshot sequence. Late updates through older recorders are ignored. Unknown free-form metric names are counted and discarded without retaining the supplied label.
- Snapshot requests copy only fixed aggregate state under a short lock and encode after release; no packet, HEV, or SSH component is polled. The maximum-value fixture encodes to 10242 bytes against the 65536-byte diagnostics limit.
- Default schema and reflection allowlists contain no lane/run/flow identifiers, DNS/destination fields, addresses, credential fields, shell commands/stdin, payload content, or traffic samples.

## Files
- Sources/ReluxTunnelCore/RuntimeDiagnostics.swift
- Sources/ReluxTunnelCore/RuntimeMessageModels.swift
- Tests/ReluxTunnelCoreTests/RuntimeDiagnosticsTests.swift
- LOGBOOK.md

## Verification
- swift test --filter RuntimeDiagnosticsTests: 8 tests in 1 suite passed.
- swift test --sanitize=thread --filter RuntimeDiagnosticsTests: 8 tests passed with no Thread Sanitizer report.
- swift test --filter RuntimeMessageCodecTests: 15 tests in 2 suites passed.
- make validate-core: core boundary and native dependency checks passed; 191 tests in 22 suites passed; post-test swift build passed.
- swift format lint --strict --recursive Sources Tests Package.swift: passed with no diagnostics.
- git diff --check: passed.
