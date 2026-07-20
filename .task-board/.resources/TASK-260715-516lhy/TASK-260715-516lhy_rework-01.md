# TASK-260715-516lhy review verdict

Verdict: CHANGES REQUESTED -> to-dev.

## Blocking finding

Both decoders apply the protocol and lowered-local MSGLEN caps before completing HEV structural validation: Swift RelayDatagramCodec.swift lines 240-245 and Go codec.go lines 701-709. The accepted TASK-260715-18owh7 decision section 4.4 is normative and requires HEV structure at step 4, then protocol/local limits at step 5.

Concrete case: with maximumPayloadLength 512, bytes 02 01 0A 01 C0 00 02 01 00 35 declare 513 DATA bytes but contain none. Both decoders currently return messageLengthExceedsLocalMaximum with rejectDatagram, allowing the association to survive. The required result is an association-fatal structural length failure because outer length does not equal HDRLEN plus MSGLEN. The same precedence issue lets other malformed over-cap records bypass HDRLEN, address, and port validation. Existing local-cap tests use only a structurally valid record; the current protocol-overflow malformed fixture actually codifies the reversed order.

## Required rework

1. In both Swift and Go, validate ATYP, recomputed HDRLEN, address bounds, port, and checked exact outer length before applying MSGLEN protocol and local-cap consequences. Preserve zero decoded materialization on every failure.
2. Add mirrored table tests for malformed-plus-local-cap and malformed-plus-protocol-limit combinations, proving structural failures close the association. Include a structurally valid 1473-byte record proving the protocol violation path, and retain the structurally valid 513-byte lowered-cap policy-drop case.
3. Keep Swift and Go error outcomes equivalent and privacy-safe; update comments and implementation evidence that currently claim all validation is complete before the early limit return.

## Independent validation

PASS: make relay-protocol-check; full swift test, 149 tests in 16 suites; Go package tests; Go FuzzDatagramCodec for 3 seconds, 1274152 executions; swift format lint strict; gofmt; core-boundary check; task-board validate; git diff --check. These green results do not clear the blocking contract gap because the combined precedence case is absent and one malformed oversized fixture expects the wrong result.

Positive review evidence: byte-exact IPv4, IPv6, and domain layouts; zero through 1472 DATA properties; maximum 1727-byte record; opaque-domain policy; response-source endpoint preservation; bounded materialization and privacy-safe diagnostics otherwise match the architecture.