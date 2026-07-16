# Build capability, failure, and recovery detail presentation

## Description
Build the shared content and platform presentation that explains current forwarding capabilities, limitations, finite reason codes, and recovery. Distinguish safe degraded service from mandatory failure and temporary reasserting without exposing traffic or endpoint details.

## Scope
In scope: full capability table, TCP, DNS, UDP, IPv4/IPv6, relay build identity where safe, degraded missing-capability explanation, QUIC implication, reasserting progress/retry facts, mandatory failure categories, last transition time, safe diagnostics link, remediation actions, unknown-version fallback, accessibility semantics, localization keys, and snapshots. Out of scope: raw counters/logs, destination data, provider state computation, policy selection controls, and marketing performance claims.

## Acceptance Criteria
1. Full, degraded, reasserting, failed, connecting, and disconnected content derives only from the current presentation model and cannot contradict the primary dashboard. 2. Degraded explicitly states TCP and leak-safe DNS availability plus missing general UDP, while failed states identify the mandatory subsystem without claiming traffic continues. 3. Reason mappings cover relay unavailable/incompatible, safe DNS loss, SSH reachability, trust/auth, tunnel setup, route/settings, memory/resource, timeout, cancellation, and unknown codes with only supported remediation. 4. Values contain no full endpoint/local address, DNS name, destination, payload, credential, or raw provider error text. 5. Snapshot and accessibility tests verify content across both platforms, long localized text, text scaling, focus, status announcements, and transition updates.
