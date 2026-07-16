# Add packet-frame fuzz and allocation-bound tests

## Description
Create a reproducible fuzz and property-test surface for untrusted packet and HEV-facing frame parsing so malformed lengths, families, and datagram sizes cannot trigger crashes, hangs, out-of-bounds access, or allocation growth.

## Scope
In scope: four-byte family headers; undersized and oversized datagrams; unknown families; random payloads; boundary MTUs; coalesced test inputs split into datagrams; corpus seeds from unit failures; deterministic property checks; allocation and runtime ceilings; crash minimization and replay. Out of scope: SSH and relay framing, kernel fuzzing, private API, performance acceptance, and treating a short fuzz run as exhaustive security proof.

## Acceptance Criteria
1. The fuzz target or deterministic Swift property harness accepts arbitrary bytes and never reads beyond frame boundaries or allocates relative to an untrusted declared length beyond the configured datagram ceiling. 2. Seed corpus covers IPv4, IPv6, empty, 1–3 byte, unknown-family, exact MTU, over-MTU, and prior regression cases. 3. CI runs a bounded deterministic corpus; a documented extended command records seed, duration, iterations, peak allocation, and source revision. 4. Any crash or invariant violation produces a minimized replay fixture and concrete bug before this task can pass. 5. Passing evidence demonstrates bounded runtime and memory for the configured corpus and asserts reason-specific malformed counters.
