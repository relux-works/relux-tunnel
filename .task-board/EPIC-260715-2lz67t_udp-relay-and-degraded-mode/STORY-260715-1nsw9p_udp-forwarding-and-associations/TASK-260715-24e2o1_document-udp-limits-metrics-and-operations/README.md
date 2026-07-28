# Document UDP associations, limits, metrics, and operations

## Description
Document the implemented full-mode UDP path and evidence from HEV through SSH exec framing to exit-host sockets, including associations, source mapping, DNS, limits, pressure behavior, privacy-safe metrics, test commands, measured ceilings, and troubleshooting.

## Scope
In scope: component and sequence diagrams; client and relay ownership; association state and ID reuse; HEV and protocol framing handoff; IPv4, IPv6, and domain behavior; DNS priority and TCP fallback; limit table; queue and drop policy; error and close table; process-loss outcome; diagnostic schema; privacy; unit, fuzz, soak, harness, iPhone, and Mac commands and results; M3 seams. Out of scope: degraded-mode user disclosure owned separately, bootstrap internals, final QUIC policy, path reconnect, performance tuning beyond measured M2 values, app release procedures, and implementation changes.

## Acceptance Criteria
1. Diagrams and tables trace one datagram and response through every component and state who owns frame, association, buffer, socket, timer, and cleanup at each boundary. 2. Exact configured and negotiated limits, hard ceilings, admission order, priority classes, saturation drops, error codes, idle expiry, and ID reuse conditions match implemented tests and diagnostics. 3. DNS documentation covers approved resolver, UDP relay priority, TC and safe TCP fallback, cache interaction, failure behavior, and zero physical resolver path. 4. Reproduction sections name local, conformance, fuzz, pressure, soak, and Apple-silicon Mac commands, marking iPhone commands as deferred under ADR-024, with expected counters, captures, memory fields, and redaction steps. 5. Troubleshooting covers address, oversize, exhaustion, queue pressure, resolution, socket, relay process, protocol, and cleanup failures and links capability, M3, and release handoffs by board ID.
