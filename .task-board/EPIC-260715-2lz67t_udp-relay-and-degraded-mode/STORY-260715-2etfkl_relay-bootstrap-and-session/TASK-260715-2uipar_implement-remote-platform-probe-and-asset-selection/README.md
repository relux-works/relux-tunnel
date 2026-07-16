# Implement remote platform probing and exact asset selection

## Description
Probe the authenticated SSH host with a bounded fixed command, normalize supported uname values, and select exactly one trusted manifest asset before any upload or dynamic path operation.

## Scope
In scope: one-shot uname -s and uname -m probe through exec; fixed command text; bounded stdout and stderr; deadline and cancellation; line and whitespace validation; Linux and Darwin normalization; x86_64, amd64 where explicitly accepted, arm64, and aarch64 mapping; exact manifest lookup; unsupported and ambiguous typed reasons; privacy-safe OS and architecture diagnostics. Out of scope: executing downloaded relay bytes, shell interpolation of profile data, version negotiation, remote directory creation, WSL or BSD support, CPU feature probing, and guessing a nearest asset.

## Acceptance Criteria
1. Canonical supported probe outputs map deterministically to Linux x86_64, Linux arm64, macOS x86_64, or macOS arm64 and select exactly one manifest entry. 2. Empty, truncated, oversized, multi-record, non-UTF8 where text is required, control-character, injected-command-like, unsupported OS, unsupported architecture, timeout, and nonzero-exit results return stable capability reasons with no upload. 3. Probe command bytes are constant and contain no hostname, username, credential, profile secret, or caller-supplied shell fragment. 4. Stdout, stderr, and process lifetime are bounded and cancellation closes the exec channel and discards incomplete state. 5. Table and fuzz tests cover real uname variants for declared targets plus hostile output and verify that diagnostics expose only normalized platform and reason code.
