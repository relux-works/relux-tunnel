# Decide the baseline exit-side DNS resolver policy

## Description
Resolve the product and architecture gap that the baseline profile fields do not identify which resolver M1 should reach through SSH. Compare explicit per-profile resolver endpoints, a documented product default, exit-host discovery, and tunneled DoH where relevant, then record one implementable privacy-safe policy and migration path.

## Scope
In scope: IPv4 and IPv6 resolver addresses, port and protocol, profile-schema impact, default behavior, reachability from the exit host, bootstrap circularity, DNSSEC transparency, TCP support, privacy and operator expectations, failure behavior, M4 UI impact, test fixtures, and future M2 relay compatibility. Out of scope: implementing DNS, selecting a public vendor without accountable approval, silently using the physical resolver, remote shell parsing without a security design, fake DNS, and final UI copy.

## Acceptance Criteria
1. A TASK-ID-scoped decision compares at least explicit profile resolver, product default, exit-host discovery, and tunneled DoH options for privacy, reliability, bootstrap, platform, UX, and operational cost. 2. The selected policy names exact profile fields and defaults, address-family rules, validation, port, transport, timeout, failure, and migration behavior. 3. It proves ordinary queries never require or fall back to the physical resolver after routes apply. 4. The accountable product and architecture owner records approval, or the task remains blocked with the exact choice and evidence still required. 5. Downstream DNS implementation, M4 profile UI, M2 relay, documentation, and validation tasks are listed by concrete ID and impact.
