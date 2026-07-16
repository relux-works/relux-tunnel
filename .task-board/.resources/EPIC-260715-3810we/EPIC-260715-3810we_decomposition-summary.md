# EPIC-260715-3810we — M1 TCP and DNS system VPN decomposition

Date: 2026-07-15
Role: solution-architect
Scope: board planning only. No implementation or source/specification change was performed.

## Outcome

- Refined all five existing stories with production boundaries, explicit in-scope and out-of-scope text, and independently verifiable acceptance criteria.
- Created 54 atomic backlog tasks. Every task has a human-readable title, substantial description, explicit scope and non-scope, five numbered acceptance criteria, and three unchecked task-specific handoff items.
- Added 135 direct task dependencies, all within M1. Exact M0 handoff outputs are attached as task preconditions rather than unfinished cross-epic blockers, so planning review is independent of M0 execution status. No A0, P0, packet-bridge, generated-target, or SSH-engine gate was recreated in M1.
- Covered contracts, implementation, unit and fault tests, fuzzing, controlled integration, large-transfer and rekey validation, physical iPhone and Mac evidence, documentation, privacy, and legacy-product isolation.
- Added an explicit blocking decision task for the previously undefined exit-side DNS resolver policy.
- Attached a canonical task-board plan plus task-scoped Graphviz and PlantUML planning diagrams.

## Existing M0 handoffs consumed

- TASK-260715-nphtib — Execute the generated-project architecture verification matrix.
- TASK-260715-2jatnd — Record the M0 packet-bridge and HEV decision.
- TASK-260715-1gjxer — Record the M0 SSH engine selection.
- TASK-260715-14lk3y — Preserve the legacy SwiftPM app and release path, consumed only by the M1 migration-isolation check.

These are documented preconditions, not duplicated M1 gates or cross-epic dependency edges. The first three are attached to TASK-260715-30zng6, the M1 runtime contract root. The legacy baseline is attached to TASK-260715-3qqbbm.

## Canonical story phases

1. STORY-260715-1y04r0 — Shared tunnel runtime and extension-owned orchestration, 9 tasks.
2. STORY-260715-2wjwuf — SSH profile authentication and host-key enforcement, 9 tasks.
3. STORY-260715-2nqxa5 — TCP SOCKS-to-SSH direct forwarding, 11 tasks.
4. STORY-260715-2bfjhn — Leak-free DNS and compatible IPv4/IPv6 routing, 12 tasks.
5. STORY-260715-eto58m — System VPN manager, provider lifecycle, and physical M1 acceptance, 13 tasks.

The critical story path is shared runtime -> SSH auth -> TCP -> DNS/routing -> provider lifecycle and physical acceptance. Task-level work still exposes parallel implementation inside each story.

## Story task inventory

### STORY-260715-1y04r0 — Shared tunnel runtime and extension-owned orchestration

- TASK-260715-30zng6 — Record the M1 runtime ownership and sequencing contract.
- TASK-260715-lovbdz — Implement versioned runtime configuration and message models.
- TASK-260715-3ejhyy — Compose accepted M0 components behind production runtime factories.
- TASK-260715-3tlgwm — Implement the extension-owned M1 TunnelRuntimeCoordinator.
- TASK-260715-1i49fm — Implement privacy-safe runtime diagnostics snapshots.
- TASK-260715-32virr — Add deterministic runtime coordinator unit and fault-injection tests.
- TASK-260715-m8bi8i — Add composed M1 runtime integration scenarios to ReluxTunnelHarness.
- TASK-260715-3qqbbm — Verify migration isolation from the legacy SwiftPM SOCKS product.
- TASK-260715-2rcvr0 — Document M1 runtime ownership, operation, and extension seams.

### STORY-260715-2wjwuf — SSH profile authentication and host-key enforcement

- TASK-260715-29ws8l — Record the SSH profile, trust, and credential boundary contract.
- TASK-260715-3f4lxy — Implement the versioned non-secret SSH profile snapshot loader.
- TASK-260715-1o9wjz — Implement the packet-extension Keychain credential resolver.
- TASK-260715-12zaq5 — Implement mandatory approved host-identity policy.
- TASK-260715-13labb — Implement SSH bootstrap errors, retry classes, and diagnostics mapping.
- TASK-260715-3t2v9w — Implement profile-driven authenticated SSH session bootstrap.
- TASK-260715-3cv3r4 — Add profile, Keychain, host-policy, and redaction unit tests.
- TASK-260715-297imp — Run the profile-driven SSH authentication integration matrix.
- TASK-260715-1m07fw — Document SSH profile, trust, credential, and operator handoffs.

### STORY-260715-2nqxa5 — TCP SOCKS-to-SSH direct forwarding

- TASK-260715-1juybj — Record the private SOCKS-to-direct-tcpip adapter contract.
- TASK-260715-b6uruh — Implement the private SOCKS endpoint and bounded CONNECT parser.
- TASK-260715-2yz8du — Implement direct-tcpip channel opening for accepted CONNECT requests.
- TASK-260715-sdnk2k — Implement the bounded full-duplex SOCKS and SSH channel pump.
- TASK-260715-1n9v9o — Implement TCP flow close, half-close, cancellation, and error semantics.
- TASK-260715-zfg9ap — Implement TCP admission limits and privacy-safe flow metrics.
- TASK-260715-1mr9j2 — Add SOCKS parser, admission-policy, and allocation fuzz tests.
- TASK-260715-1dbmph — Add direct-channel and byte-pump conformance tests.
- TASK-260715-1s9gku — Add end-to-end HEV-to-SSH TCP integration tests.
- TASK-260715-1gvdtz — Run the integrated M1 TCP concurrency and rekey matrix.
- TASK-260715-2voayq — Document M1 TCP forwarding and reserved M3 scheduler seams.

### STORY-260715-2bfjhn — Leak-free DNS and compatible IPv4/IPv6 routing

- TASK-260715-1tnjlu — Decide the baseline exit-side DNS resolver policy.
- TASK-260715-2pml0c — Record the M1 compatible routing, virtual address, and DNS contract.
- TASK-260715-2tj2pb — Integrate pre-route SSH bootstrap and narrow endpoint exclusions.
- TASK-260715-12tbjl — Implement the compatible-mode Network Extension settings builder.
- TASK-260715-1e0x1u — Implement the tunnel-owned UDP and TCP DNS listener.
- TASK-260715-5o6jqg — Implement exit-side DNS-over-TCP through SSH direct-tcpip.
- TASK-260715-2hawz9 — Implement bounded DNS caching, truncation, and fallback semantics.
- TASK-260715-30ugfm — Integrate safe routing and DNS startup and failure ordering.
- TASK-260715-393tuu — Add DNS protocol, cache, fault, and allocation-bound tests.
- TASK-260715-293sz3 — Add dual-stack route and SSH endpoint exclusion tests.
- TASK-260715-336ljl — Add integrated tunneled DNS, external-IP, and no-leak harness tests.
- TASK-260715-1o4h97 — Document compatible routing, leak-free DNS, and Apple exceptions.

### STORY-260715-eto58m — System VPN manager, provider lifecycle, and physical M1 acceptance

- TASK-260715-1q4qhw — Record the system VPN configuration and lifecycle contract.
- TASK-260715-15vkvz — Implement the owned NETunnelProviderManager repository.
- TASK-260715-1rsqrh — Implement VPN session control and truthful status projection.
- TASK-260715-1bp6eu — Implement provider message routing and deterministic stop cleanup.
- TASK-260715-2hiabd — Implement the thin iOS packet-tunnel provider adapter.
- TASK-260715-3dv8ea — Implement the thin macOS packet-tunnel provider adapter.
- TASK-260715-3lab1f — Add VPN manager and provider lifecycle automation.
- TASK-260715-3f4rhy — Verify SSH authentication inside physical packet-tunnel providers.
- TASK-260715-13gzxe — Verify iPhone VPN lifecycle and UI-process independence.
- TASK-260715-12x6oq — Verify Mac VPN lifecycle and UI-process independence.
- TASK-260715-2qr5aj — Verify iPhone IPv4, IPv6, routing, external-IP, and DNS leak behavior.
- TASK-260715-2wqffe — Verify Mac IPv4, IPv6, routing, external-IP, and DNS leak behavior.
- TASK-260715-1fpr3u — Document VPN installation, control, state, and recovery.

## Gap closure and deliberate boundaries

- The two immediately unblocked planning tasks are TASK-260715-30zng6, which records the runtime contract against attached M0 handoff preconditions, and TASK-260715-1tnjlu, which resolves whether resolver selection is explicit per profile, a documented default, exit-host discovery, or tunneled DoH. Production composition cannot be accepted without the named M0 outcomes, and DNS code is blocked until an accountable resolver policy and schema decision exists.
- Physical provider evidence was consolidated into STORY-260715-eto58m. This prevents a circular story dependency while leaving SSH, TCP, and DNS with deterministic core and harness gates.
- M1 reports independent TCP, safe-DNS, UDP, route-mode, and health facts. It cannot claim M2 full capability while UDP is absent.
- M1 implements one authenticated baseline SSH session. Multi-lane scheduling, live-flow behavior across lane loss, QUIC policy, reconnect, memory watermarks, and fail-closed mode remain M3 work.
- General UDP, relay deployment, and formal full versus degraded relay capability remain M2 work. Profile editing and trust UI remain M4. Distribution and App Review remain M5.

## Planning artifacts

- EPIC-260715-3810we_canonical-plan.md — canonical task-board phase snapshot.
- TASK-260715-30zng6_m1-dependency-plan.dot — focused Graphviz dependency diagram attached to the runtime-contract task.
- TASK-260715-30ugfm_safe-startup-sequence.puml — leak-safe startup and failure sequence attached to the routing integration task.
- EPIC-260715-3810we_diagram-validation-01.log — render-tool anomaly and disposition.

## Verification

- task-board validate: board valid with no issues.
- Structured audit: 54 tasks, 54 unique IDs, 54 unique names, zero default titles, zero weak descriptions, zero incomplete scopes, zero placeholder acceptance criteria, zero missing task-specific checklists, and every task in backlog.
- Dependency audit: 135 direct links, all within M1. Four exact M0 handoffs are recorded in task precondition resources rather than dependency edges.
- Canonical epic plan: five stories, five phases, no cycle, critical path shared runtime -> SSH -> TCP -> DNS -> provider and physical acceptance.
- Graphviz PNG rendering is not claimed because the local dot binary cannot load libltdl.7.dylib. The diagrams-as-code and canonical plan remain readable and attached.

## Handoff state

All five stories are in to-dev and unassigned. All 54 tasks remain unstarted in backlog. M0 execution remains a production precondition recorded on the root tasks. The planning epic itself has no unfinished cross-epic blocker and its solution-architecture decomposition is prepared for review.