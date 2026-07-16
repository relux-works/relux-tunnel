# Implement provider message routing and deterministic stop cleanup

## Description
Implement the shared provider-side router for versioned snapshot, diagnostics, and control messages plus the bounded cleanup coordinator used by both platform adapters when Network Extension requests stop or the runtime fails.

## Scope
In scope: payload size and version validation, read-only snapshot and diagnostics requests, permitted control commands, serialized routing, one reply per request, unknown-command errors, stop reason capture, cleanup deadline policy, cancellation fan-out, completion once, and privacy-safe logging. Out of scope: arbitrary RPC, profile or secret mutation, interactive trust approval, runtime business logic, unbounded log export, reconnect, and platform-specific duplicate implementations.

## Acceptance Criteria
1. Supported messages have one versioned request and response path, bounded payloads, stable errors, and no ability to read or write secret material. 2. Unknown, malformed, oversized, future-version, duplicate, and concurrent messages cannot crash, block, or mutate an invalid runtime generation. 3. Stop prevents new commands, cancels the active runtime, drains or force-closes owned resources within the documented deadline, and completes exactly once. 4. A provider failure reports the mapped reason before cleanup when possible and never leaves routes advertised after mandatory forwarding is gone. 5. Shared tests run against both provider adapters and prove reply, cancellation, deadline, late-callback, and deallocation behavior.
