# Goal — Relux Tunnel, macOS-first v1

## Objective
Deliver a production, notarized **macOS full-tunnel system VPN** whose external
transport is one or more authenticated SSH connections to a user-controlled
host. To the OS it is a system VPN (`NEPacketTunnelProvider`); on the wire it is
SSH to the user's own machine. Execute the relux-tunnel board's autonomous work
to completion and halt cleanly at the irreducible human gates. iOS is deferred.

## Definition of done for this goal
The ~120 gate-free board tasks — M0 spike core; M1 TCP/DNS runtime + macOS
provider adapter; M2 relay protocol/UDP/degraded mode; macOS self-update;
threat model; CI quality gates — are implemented, unit/integration-tested on the
SPM `ReluxTunnelHarness`, reviewer-accepted, and marked `done` on the board, up
to the point where progress requires A0 evidence, Apple provisioning, a physical
Mac, or a human decision. At that boundary work stops with evidence attached —
never a workaround.

## Scope
**IN** — everything buildable/testable on a Mac via the SPM harness without a
device, Apple-portal provisioning, or human approval: ReluxTunnelCore; the public
`AF_UNIX/SOCK_DGRAM` PacketFlow bridge; HEV/lwIP integration; both SSH engine
candidates (ReluxNIOSSH fork + libssh2) with conformance/rekey tests against a
real SSH host; the wire protocol + codecs; rootless relay logic + degraded mode;
the macOS provider adapter (write + unit-test); the self-update pipeline; the
threat model; CI; reproducible relay build.
**OUT** — iOS targets/UI/provider/TestFlight/App Store/App Review; anything that
needs the generated Xcode workspace's signed extension to actually run; and the
engine/bridge/HEV-fork/tuning **selections** that require physical-hardware
numbers.

## Execution model
Board-driven via `task-board` in `/Users/iv/Developer/relux-tunnel`. The
orchestrator plans from the critical path and delegates every task to tracked
background children per `docs/spawn-policy.md` — **Fable-5 orchestrator; Codex
`gpt-5.6-sol` at `high` as executor #1; `max_parallel` 1** (one executor at a
time). Each task runs producer → reviewer → rework → accepted `done`; never stop
at `to-review`. Respect dependency links; sequence dependent work. **After each
accepted task: clean worktree, push to remote, sync local.** Current entry
points:
`1fv4z1` (project inventory), `uopycx` (HEV baseline), `28ok1k` (SSH engine
audit), plus always-free `3ujeip` (threat model), `2uyfn5` (self-update),
`1s2eiz` (CI), `1tnjlu` (DNS policy), `2kchi0` (perf protocol).

## Invariants (do not violate)
- Honor the ADR log (`.spec/decisions.md`): local TCP termination +
  `direct-tcpip` (no TCP-over-TCP); HEV/lwIP, no hand-rolled TCP stack; public
  packetFlow bridge, no utun-FD discovery; rootless exec/stdio relay, no SFTP;
  full + degraded modes.
- Security (`.spec/security-privacy.md`, `.spec/threat-model.md`): mandatory
  host-key verification before user auth; secrets only in the Keychain — never in
  `providerConfiguration`, logs, shell commands, or board resources;
  bounded-memory parsers; fail-closed DNS; the internal SOCKS boundary is not a
  user-reachable proxy.
- Develop the core on the SPM harness **in parallel** with the manual gates
  (ADR-011); do not re-couple core work to the A0/P0-gated generated workspace.
- Numeric/policy values stay evidence gates — do not hardcode a "final" MTU,
  channel window, lane count, or SSH engine; keep them injectable pending physical
  selection. Verify non-trivial changes by exercising behavior, not tests alone.
- Do not force-fit: if a task starts requiring compensating hacks around a
  platform/product constraint, stop and escalate with evidence.

## Stop-the-line — the 5 irreducible manual gates
When the critical path reaches one of these, mark the task `blocked` with the
evidence packet (constraint, options, exact human input needed) and surface it:
1. **Gate A0** — Apple packet-tunnel intended-use evidence (`1i6bh7` → `1828xy`).
2. **Apple provisioning** — account readiness + App IDs/entitlements/profiles
   (`apc34w` → `ypo7yo` → `3jloqy`).
3. **Gate P0** — run the signed provider on a physical Apple-silicon Mac with
   system-VPN approval (`9yp8to` → `2ayxqn`).
4. **macOS physical validation** — lifecycle / routing / DNS-leak / UDP /
   degraded on a real Mac, led by `12x6oq` (also gated on the engine+bridge
   selection, preserving evidence discipline).
5. **Release ceremonies** — Developer ID/notary environment (`3gkwn0`) and the
   Sparkle EdDSA update-signing key (`ziprhs`).

## Success signal
All autonomous tasks accepted `done`; the SPM harness demonstrates the packet
bridge, HEV, a conformant SSH engine, TCP + leak-free DNS forwarding, and a
relay round-trip end-to-end on macOS; and the board's only remaining open items
are exactly the five human gates, each with a clear ask. A human then runs those
gates, and the signed, notarized macOS VPN ships with working in-app self-update.
