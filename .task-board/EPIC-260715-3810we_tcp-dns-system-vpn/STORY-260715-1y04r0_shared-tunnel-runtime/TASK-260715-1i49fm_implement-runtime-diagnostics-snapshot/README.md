# Implement privacy-safe runtime diagnostics snapshots

## Description
Implement bounded aggregate runtime metrics and immutable versioned diagnostic snapshots sourced from the coordinator, packet bridge, HEV, SSH, TCP, DNS, and route layers without exposing traffic destinations, DNS names, payloads, credentials, or full local addresses.

## Scope
In scope: state transition times, component health, lane-neutral SSH counters, packets and bytes, queue drops by reason, active and peak flow counts, DNS result classes and latency buckets, route mode, memory samples, error domain and code, snapshot size bounds, and redaction tests. Out of scope: analytics upload, packet capture, destination logging, support-export UI, raw SSH commands, profile secrets, and M3 detailed lane telemetry.

## Acceptance Criteria
1. Snapshot schema is versioned, immutable, size-bounded, and can be requested without blocking packet or SSH executors. 2. Counters are monotonic within a generation and reset or label generations explicitly across reconnect or restart. 3. Default data contains no private keys, passphrases, DNS names, destination hostnames or IPs, payload bytes, full local addresses, or shell stdin. 4. Concurrent update and snapshot tests show consistent output without unbounded retention or high-cardinality labels. 5. Redaction and golden-schema tests fail when prohibited fields or unstable identifiers are introduced.
