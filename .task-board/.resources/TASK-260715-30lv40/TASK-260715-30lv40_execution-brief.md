# Capability state, reason, and ownership contract

Produce the binding M2 capability contract for `TASK-260715-30lv40` using the accepted M1 runtime handoff, ADRs, relay binding/schema/limits work, DNS fail-closed policy, and full/degraded product requirement.

Requirements:

1. Define one finite state machine covering connecting/bootstrap, full, degraded, failed, stopping, and relay-only reprobe/reasserting-compatible substates. For every state and transition list entry predicate, owned resources/generation, traffic allowed, capability bits, safe-DNS predicate, reason, cleanup, retry/reprobe eligibility, and terminal disposition.
2. Full requires authenticated SSH plus mandatory packet/TCP path, safe DNS, and a validated live relay session. Degraded preserves the same mandatory base while UDP is unavailable. Failed advertises no usable traffic. No state may imply absolute OS kill-switch guarantees.
3. Define stable finite reason codes for unsupported platform/assets, bootstrap/checksum/launch/version/feature/limit/framing/health/process/lane/DNS/stale-generation/stop failures. Remote strings never become reason codes or diagnostics.
4. Make provider live state the authority. Snapshots must be schema-versioned, monotonic-generation scoped, truthful under late callbacks, and privacy-safe. Specify app-message/UI projection without giving the UI ownership of runtime truth.
5. Assign relay-only reprobe to M2 and path/host/route/lane/sleep/NAT64/captive reconnect to M3. Identify M1 seams and avoid contradictory retry owners or parallel reconnect loops.
6. Preserve numeric values as injected policy/evidence gates; do not select a final SSH engine, MTU, lane/window, or timing value here. Record unresolved physical/evidence gates explicitly.
7. Add compact PlantUML diagrams only where they materially clarify lifecycle/ownership, validate them if tooling exists, update the relevant specs/downstream task resources, and attach a task-scoped contract outcome plus reviewer packet.
8. Security/privacy is stop-the-line: no credentials, destinations, DNS queries, payloads, host identifiers, remote-controlled strings, or raw spawn logs in versionable artifacts.

Use one Codex `gpt-5.6-sol` high executor, no delegation and no Claude. If existing accepted contracts conflict, stop with the exact contradiction instead of inventing a compensating state.
