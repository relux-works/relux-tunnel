# EPIC-260715-2lz67t decomposition summary

## Outcome

All five existing M2 stories now have explicit descriptions, in-scope and out-of-scope boundaries, and five verifiable acceptance criteria. The board contains 52 atomic backlog tasks, each with a clear title, description, scope, five acceptance criteria, and three task-specific handoff checklist items.

Task counts:

- STORY-260715-18ncz1 — 10 tasks
- STORY-260715-3pv7qc — 8 tasks
- STORY-260715-2etfkl — 10 tasks
- STORY-260715-1nsw9p — 12 tasks
- STORY-260715-2ungml — 12 tasks

All five stories are at to-dev. All implementation, test, validation, and documentation tasks remain unstarted at backlog.

## Canonical path

The canonical task-board plan is:

1. STORY-260715-18ncz1 — relay protocol v1 and cross-language conformance
2. STORY-260715-3pv7qc — portable relay builds, manifests, and supply-chain boundaries
3. STORY-260715-2etfkl — secure exec bootstrap and managed relay session
4. STORY-260715-1nsw9p — bounded UDP forwarding and association lifecycle
5. STORY-260715-2ungml — explicit capability negotiation and leak-safe degraded mode

The 125 direct within-M2 task links connect generated protocol constants, vectors, hostile-input gates, four target assets, manifest integrity, authenticated exec upload, private atomic install, session health, HEV associations, exit-host UDP and DNS, resource ceilings, full or degraded transitions, leak tests, and separate physical iPhone and Mac evidence.

## External prerequisites

Exact foundation and M1 handoffs are attached to each consuming task as task-ID-scoped precondition resources. They are not active cross-epic dependency edges because task-board prevents a planning epic from reaching its required to-review handoff while upstream epics remain at to-review. Spawned implementers receive these preconditions and must verify acceptance before production integration.

The preserved handoffs cover:

- TASK-260715-1828xy and TASK-260715-32umrc — Gate A0, generated project, and relay-toolchain architecture
- TASK-260715-1gjxer and TASK-260715-3t2v9w — selected SSH engine and authenticated exec-capable session
- TASK-260715-1vv52g — unmodified HEV with socks5.udp tcp
- TASK-260715-30zng6, TASK-260715-lovbdz, and TASK-260715-1i49fm — runtime ownership, versioned models, and diagnostics
- TASK-260715-1tnjlu, TASK-260715-1e0x1u, TASK-260715-5o6jqg, and TASK-260715-2hawz9 — resolver decision, tunnel-owned listener, SSH DNS-over-TCP, and cache or TC behavior
- TASK-260715-336ljl, TASK-260715-2qr5aj, and TASK-260715-2wqffe — composed and physical M1 routing and leak baselines

## Explicit decision and safety gaps

- TASK-260715-18owh7 is the explicit blocking decision for the mismatch between protocol v1, which carries only features and maxFrame, and the broader requirement to negotiate association, queue, datagram, and idle limits. It blocks schema, client and relay registries, resource policy, and capability snapshots through real M2 links.
- TASK-260715-2zmw58 consumes the existing M1 resolver decision rather than creating a second resolver choice. Its task precondition preserves TASK-260715-1tnjlu as the accountable upstream input.
- Remote checksum fallback is specified as bounded readback plus client-side SHA-256 when approved hash utilities are absent. Protocol self-hash is secondary identity evidence only, so a known mismatch is never executed.
- M2 owns relay-only reprobe on a healthy authenticated base SSH transport. Path, route, host, lane-pool, sleep, NAT64, captive, and fail-closed reconnect remain M3.
- M2 owns pinned relay source, four builds, hashes, manifest, notices, and scoped provenance. Application signing, notarization, attestation, and distribution approval remain M5.

## Planning artifacts

- EPIC-260715-2lz67t_canonical-plan.md
- EPIC-260715-2lz67t_dependency-plan.dot
- TASK-260715-111tde_protocol-boundaries.puml
- TASK-260715-159pcp_bootstrap-trust-sequence.puml
- TASK-260715-1loqwb_udp-data-path.puml
- TASK-260715-30lv40_capability-state-plan.puml
- EPIC-260715-2lz67t_logbook.md
- EPIC-260715-2lz67t_diagram-validation.log

## Verification

task-board validate reported no issues. The canonical plan reports five phases and the expected five-story critical path. All 52 tasks are backlog with three unchecked task-specific handoff items. Graphviz rendering could not run because the installed dot binary is missing libltdl.7.dylib; source diagrams and the canonical plan are attached, and the environment anomaly is recorded separately.

No implementation, source, test, configuration, or specification file was edited.