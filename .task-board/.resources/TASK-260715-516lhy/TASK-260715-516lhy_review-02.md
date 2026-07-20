# TASK-260715-516lhy — review round 2

Verdict: ACCEPTED.

The prior structural-before-limit defect is resolved in both implementations. Swift RelayDatagramCodec validates ATYP, recomputed HDRLEN, address bounds, port presence/nonzero value, available DATA, and checked exact outer length before the protocol ceiling and lowered local cap. Go DatagramCodec applies the equivalent order. Neither decoder materializes decoded address or DATA bytes before successful validation.

Mirrored Swift and Go tables exercise malformed 513-byte lowered-cap and malformed 1473-byte protocol-limit declarations across unknown ATYP, wrong HDRLEN, truncated address, truncated port, zero port, and inconsistent outer length. Each returns a bounded association-close structural error with zero decoded materialization. Structurally valid 1473-byte records remain association-fatal protocol violations; structurally valid 513-byte records under a 512-byte local cap remain survivable policy rejects.

The complete implementation also satisfies the original AC: literal HEV IPv4, IPv6, and domain layouts round-trip byte exactly at zero, typical, and 1472-byte DATA; all permitted DATA sizes and the 1727-byte maximum record are covered; domain bytes remain opaque in the codec; response-source endpoints are preserved; encoder sizing and error diagnostics are bounded and privacy-safe.

Independent validation on 2026-07-20 passed: make relay-protocol-check; full swift test with 150 tests in 16 suites; swift format lint --strict --recursive Sources Tests; gofmt; Go vet/tests through the repository smoke harness; FuzzDatagramCodec for 3 seconds with 1,313,720 executions; scripts/check-core-boundaries.sh; task-board validate; and git diff --check. The available Go toolchain is 1.25.5; the authoritative Go 1.26.5 module/toolchain remains owned by TASK-260715-27uz4n and is not a defect in this task.