# Fresh reviewer contract 02

Independently review the rework against TASK-260715-1ue4oy_reviewer-results-20260819.md and rework-contract-01. Do not trust producer checklist marks or summaries.

Required independent checks:
- Audit descriptor ownership, O_NOFOLLOW coverage, fstat-before-allocation size gates, manifest hard cap, streaming hash/identity logic, and every close/error path for TOCTOU, fd leak, and unbounded allocation.
- Audit randomized sibling staging, atomic replacement/exchange portability, recovery from stale/partial output, ownership-aware cleanup, and behavior under interruption/race. Ensure cleanup cannot delete a raced foreign path.
- Run the focused 14-test negative suite and add/reproduce any missing adversarial case.
- Confirm deterministic generation from the accepted TASK-260715-24icoz archive and exact four identities.
- Run black --check over every modified Python file; provider graph, workspace, unsigned macOS products, core boundaries, relay protocol, and broad Swift tests proportionately.
- Confirm no real VPN, signing, install, provider launch, NetworkExtension preference, route, or DNS mutation.
- If accepted, record a new verdict artifact and hand off acceptance per board policy. If any finding remains, route to to-dev with exact reproduction.

The reviewer is fresh and must not rely on producer-checked review-only checklist items.