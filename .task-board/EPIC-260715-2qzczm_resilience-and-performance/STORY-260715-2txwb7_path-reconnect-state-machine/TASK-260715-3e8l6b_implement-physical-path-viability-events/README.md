# Implement normalized physical-path and viability event sources

## Description
Implement the platform adapter that observes physical path, interface availability, transport viability, and lifecycle hints and emits bounded coalesced generation-neutral events to the reconnect state machine without performing recovery itself.

## Scope
In scope: NWPath-derived status, interface candidates, expensive and constrained flags where relevant, IPv4 and IPv6 capability, transport viability updates, path change identity, sleep and wake hint input, subscription lifecycle, event coalescing and debounce hook with injected clock, current snapshot request, cancellation, privacy-safe family and interface-type metrics. Out of scope: resolving or connecting the SSH host, selecting route modes, applying network settings, deciding retry, opening lanes, captive portal probing beyond platform path evidence, or logging local addresses.

## Acceptance Criteria
1. The adapter emits one normalized initial snapshot and ordered change events containing only contract-approved interface types, family availability, status, viability, monotonic time, and source generation. 2. Rapid duplicate or equivalent changes coalesce within a configured bounded budget while a materially different path, unavailable state, or viability loss is never suppressed. 3. Multiple interfaces are represented without assuming a universal priority, and selection inputs remain separate from recovery decisions. 4. Start, cancellation, provider stop, resubscribe, late platform callback, and callback reentrancy produce at most one active observer and no events after terminal teardown. 5. Fake platform and clock tests cover Wi-Fi, cellular, Ethernet where supported, IPv4, IPv6, dual stack, unavailable, viability loss, rapid churn, sleep or wake hints, stale callbacks, and redaction.
