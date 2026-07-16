# Implement congestion-aware new-flow scheduling and immutable pinning

## Description
Implement the deterministic scheduler that classifies each new control, DNS, ordinary, or likely-bulk flow from allowed metadata, filters ineligible lanes, chooses one lane from current congestion evidence, and records an immutable assignment until close.

## Scope
In scope: channel-policy input from the private SOCKS or control path; port and best-effort non-sensitive destination metadata; control and DNS priority; ordinary and likely-bulk class; lane eligibility; congestion score or ordered comparison; deterministic tie-break; admission rejection; assignment registry; close cleanup; lane D prospective-only behavior; aggregate metrics. Out of scope: deep packet inspection, logging destinations, learning from payloads, migrating an open flow, changing TCP bytes, opening or recovering lanes, final threshold tuning, or route policy.

## Acceptance Criteria
1. Every channel-open request receives exactly one deterministic lane assignment or one bounded typed rejection from a current health generation. 2. Control and latency-sensitive DNS use eligible control capacity according to the contract, ordinary traffic uses eligible general capacity, and likely bulk traffic may use D only at initial assignment. 3. The assignment remains fixed for the flow lifetime, including later congestion or bulk detection, and registry cleanup occurs exactly once on every close, rejection, cancellation, and lane failure path. 4. Missing or stale metrics, tied scores, all-lanes-busy, rekey, pressure, server limits, and stale generation have documented deterministic outcomes without unbounded waiting or side queues. 5. Table and property tests distribute synthetic loads as specified, preserve control priority, prove no migration, reconcile opens and closes, and expose only aggregate assignment and rejection counters.
