# EPIC-260715-2qzczm M3 decomposition summary

## Outcome

- Six existing stories now have explicit descriptions, in-scope and out-of-scope boundaries, and verifiable acceptance criteria.
- Forty-nine atomic tasks were created with descriptions, scope and non-scope, acceptance criteria, and three task-specific checklist gates each.
- Every task remains unstarted in backlog.
- Every detailed story is in to-dev and unassigned for implementation pickup.
- Cross-epic and cross-story dependencies are linked and the board validates without a cycle.
- Six task-scoped diagram resources and this epic-scoped summary were added through task-board.
- No implementation, source, specification, configuration, commit, push, or pull-request work was performed.

## Story and task inventory

### STORY-260715-2indo6 — Production SSH lane pool and congestion-aware scheduler

1. TASK-260715-3f9kv8 — Record the production lane-pool and scheduler contract.
2. TASK-260715-3gj0ad — Implement lane-pool lifecycle and same-host identity enforcement.
3. TASK-260715-k6qq13 — Implement lane health, congestion, and admission signals.
4. TASK-260715-2px5ap — Implement congestion-aware new-flow scheduling and immutable pinning.
5. TASK-260715-1cj49i — Implement lane-local failure and control-lane recovery handoff.
6. TASK-260715-1gz4r9 — Add lane-pool scheduler and failure-injection tests.
7. TASK-260715-37eem9 — Run the physical multi-lane head-of-line and loss matrix.

### STORY-260715-1zzt0c — Channel windows, rekey, and extension memory controls

1. TASK-260715-1pn983 — Record the cross-layer memory, window, and rekey contract.
2. TASK-260715-3kimon — Implement per-channel receive-window and budget policy.
3. TASK-260715-s3at1l — Implement automatic byte, time, and server rekey coordination.
4. TASK-260715-3j3luy — Implement rekey lane isolation and bounded recovery.
5. TASK-260715-3kjhkw — Implement advisory memory sampling and watermark state control.
6. TASK-260715-318m1v — Enforce ordered pressure actions and reconnect-overlap reservations.
7. TASK-260715-200jez — Add window, rekey, memory, and allocation-bound fault tests.
8. TASK-260715-1k3wsk — Run the physical rekey, memory-pressure, and soak matrix.

### STORY-260715-2txwb7 — Path-aware reconnect and route-safe reasserting state machine

1. TASK-260715-1zikbu — Record the reconnect state, generation, and ownership contract.
2. TASK-260715-3e8l6b — Implement normalized physical-path and viability event sources.
3. TASK-260715-2s8zr1 — Implement physical-interface endpoint retry and reconnect.
4. TASK-260715-1j30es — Implement the generation-safe reconnect and retry coordinator.
5. TASK-260715-2lodgq — Implement atomic SSH endpoint exclusion and settings replacement.
6. TASK-260715-3ddzdd — Integrate reasserting and leak-safe capability restoration.
7. TASK-260715-2drjj5 — Add reconnect state, retry, route, DNS-leak, and cleanup tests.
8. TASK-260715-3hvz8n — Run the physical Wi-Fi, cellular, loss, and endpoint reconnect matrix.

### STORY-260715-21c23x — Explicit QUIC behavior and compatible or fail-closed route modes

1. TASK-260715-1je8v2 — Record the QUIC and route-mode policy contract.
2. TASK-260715-3hxnbt — Implement destination UDP/443 classification and bounded fast failure.
3. TASK-260715-2imxt0 — Implement the Auto QUIC lane-health evaluator.
4. TASK-260715-3gv53h — Integrate Allow, Block, and Auto QUIC with capability generations.
5. TASK-260715-1xsybm — Implement validated compatible and fail-closed network settings.
6. TASK-260715-3425xv — Integrate route-mode startup, change, reconnect, rollback, and stop.
7. TASK-260715-pmg702 — Add QUIC, route-policy, rollback, and leak fault tests.
8. TASK-260715-gfptap — Run the physical QUIC and route-safety matrix.

### STORY-260715-3ao1u9 — NAT64, sleep-wake, captive-network, and lifecycle hardening

1. TASK-260715-14u9bo — Record the NAT64, sleep, captive, and lifecycle device matrix.
2. TASK-260715-330cst — Implement NAT64 and endpoint-family transition hardening.
3. TASK-260715-2bo0xl — Implement sleep-wake reconnect coalescing and cancellation.
4. TASK-260715-3rqfao — Implement captive-network recovery state handling.
5. TASK-260715-npvvmd — Add NAT64, sleep, captive, app-termination, and lifecycle fault tests.
6. TASK-260715-1a1fwv — Run the physical iPhone NAT64, sleep, captive, and lifecycle matrix.
7. TASK-260715-2wnw59 — Run the physical Mac IPv6, sleep, captive, and lifecycle matrix.
8. TASK-260715-1h2nc3 — Document the verified Apple platform exception and support matrix.

### STORY-260715-19ii11 — Evidence-led packet, transport, memory, and energy tuning

1. TASK-260715-2kchi0 — Record the M3 performance measurement and evidence protocol.
2. TASK-260715-1r6k4t — Implement unified bounded resource and performance instrumentation.
3. TASK-260715-1ok93q — Build the reproducible resilience benchmark and failure-injection harness.
4. TASK-260715-k5uxim — Capture the untuned physical iPhone and Mac reference baselines.
5. TASK-260715-38o3xg — Tune packet bridge, HEV, MTU, buffer, batch, and memory parameters.
6. TASK-260715-kblh3k — Tune lane, window, rekey, and Auto QUIC parameters.
7. TASK-260715-2i7mld — Tune reconnect, memory-watermark, overlap, retry, and energy parameters.
8. TASK-260715-3mnqn8 — Decide the HEV fork gate from Instruments evidence.
9. TASK-260715-yjpk5a — Conditionally implement the approved minimal HEV callback-ingress fork.
10. TASK-260715-ixevcp — Run and publish the final M3 resilience and performance acceptance matrix.

## Dependency model

Existing upstream gates are linked by concrete task ID:

- TASK-260715-1gjxer — Record the M0 SSH engine selection.
- TASK-260715-2jatnd — Record the M0 packet-bridge decision.
- TASK-260715-3t2v9w — Implement profile-driven authenticated SSH session bootstrap.
- TASK-260715-2voayq — Document the TCP forwarding contract and M3 seams.
- TASK-260715-12tbjl — Implement the compatible-mode Network Extension settings builder.
- TASK-260715-293sz3 — Add dual-stack route and SSH endpoint exclusion tests.
- TASK-260715-30ugfm — Integrate safe routing and DNS startup and failure ordering.
- TASK-260715-30lv40 — Record the capability state, reason, and ownership contract.
- TASK-260715-3260rm — Integrate the selected degraded safe-DNS transport.
- TASK-260715-z37ay7 — Enforce UDP resource limits and DNS priority.
- TASK-260715-uh8kk6 — Enforce degraded UDP rejection and zero-fallback policy.
- TASK-260715-2y78ah — Add degraded routing, DNS leak, and recovery integration tests.
- TASK-260715-3nkhry — Verify iPhone full, degraded, failed, and relay-restoration behavior.
- TASK-260715-10phgg — Verify Mac full, degraded, failed, and relay-restoration behavior.

The M3 parent critical path is:

Production lane pool -> channel windows and memory -> path reconnect -> QUIC and route modes -> NAT64 and lifecycle -> performance and tuning.

Key cross-story links include:

- Lane lifecycle and health feed rekey isolation, reconnect failure ownership, Auto QUIC, and instrumentation.
- The memory ledger and pressure executor gate reconnect replacement reservations and sleep-wake overlap.
- Reconnect owns the generic current-generation endpoint and settings transaction.
- Route-mode work composes compatible or fail-closed settings after the reconnect transaction seam, preventing reciprocal story blocking.
- NAT64, sleep, and captive validation consume reconnect, route-mode, memory, and M2 capability evidence.
- Untuned baseline capture waits for every M3 physical implementation matrix.
- Packet, transport, and reconnect tuning run from the same locked baseline.
- The HEV implementation task is blocked by the Instruments decision and is closed without code when the gate is negative.
- Locked M3 acceptance waits for all tuning decisions, platform support evidence, and the conditional HEV task disposition.

## Coverage verification

- Failure injection: TASK-260715-1gz4r9, TASK-260715-200jez, TASK-260715-2drjj5, TASK-260715-pmg702, TASK-260715-npvvmd, and TASK-260715-1ok93q.
- Physical-device matrices: TASK-260715-37eem9, TASK-260715-1k3wsk, TASK-260715-3hvz8n, TASK-260715-gfptap, TASK-260715-1a1fwv, TASK-260715-2wnw59, TASK-260715-k5uxim, and TASK-260715-ixevcp.
- Observability: lane health in TASK-260715-k6qq13, memory state in TASK-260715-3kjhkw, capability sequencing in TASK-260715-3ddzdd, and unified bounded metrics in TASK-260715-1r6k4t.
- Bounded memory and backpressure: the ledger, windows, watermarks, pressure actions, allocation tests, soak, and packet or HEV tuning are explicit work with reconnect overlap included.
- Route and DNS safety: exact endpoint exclusions, safe-DNS readiness, reasserting, compatible and fail-closed modes, sentinels, authorized captures, NAT64, captive behavior, and platform exceptions are separately specified and tested.
- Evidence-led tuning: the protocol, instrumentation, harness, untuned baseline, three tuning decisions, Instruments fork gate, and locked acceptance matrix form an auditable before-and-after chain.
- Privacy: task criteria prohibit payloads, DNS names, destinations, credentials, full local addresses, remote-controlled text, and unbounded high-cardinality metrics.

## Planning artifacts

- TASK-260715-3f9kv8_lane-assignment-plan.puml — lane assignment activity.
- TASK-260715-1pn983_memory-pressure-plan.puml — pressure state and ordered action model.
- TASK-260715-1zikbu_reconnect-state-plan.puml — reconnect and reasserting lifecycle.
- TASK-260715-1je8v2_quic-policy-plan.puml — UDP/443 policy activity.
- TASK-260715-1je8v2_route-mode-plan.puml — compatible and fail-closed settings transaction.
- TASK-260715-2kchi0_m3-dependency-plan.dot — M3 critical-path and tuning dependency graph.
- EPIC-260715-2qzczm_logbook.md — architecture findings, anomaly resolution, and retained invariants.

## Remaining evidence and accountable decisions

These are explicit downstream gates rather than decomposition ambiguity:

1. TASK-260715-1gjxer selects the production SSH engine only after the M0 matrix.
2. TASK-260715-2jatnd records the accepted packet bridge, MTU, buffer, batch, and HEV baseline.
3. TASK-260715-1tnjlu owns the accountable exit-side DNS resolver policy decision consumed by M2 safe DNS and therefore M3 reconnect.
4. TASK-260715-14u9bo records exact named hardware, OS, network fixtures, and unavailable-row rules before physical lifecycle execution.
5. TASK-260715-38o3xg, TASK-260715-kblh3k, and TASK-260715-2i7mld select numeric parameters only from the locked untuned baseline.
6. TASK-260715-3mnqn8 decides whether Instruments evidence permits a HEV fork, with TASK-260715-yjpk5a providing the conditional implementation path.
7. Physical route-mode and captive results may expose OS-specific changes. TASK-260715-1h2nc3 records each red or unavailable row, owner, reproduction, and regression trigger.

No additional human-only decision is required to understand or pick an unblocked task. Existing accountable gates remain visible as dependencies.

## Validation evidence

- task-board validate: Board is valid. No issues found.
- Story task counts: 7, 8, 8, 8, 8, and 10, totaling 49.
- Every story child plan produced ordered phases and a critical path without a cycle.
- All six stories are to-dev.
- All 49 tasks remain backlog.
