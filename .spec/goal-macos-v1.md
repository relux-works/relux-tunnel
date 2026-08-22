# Goal — Relux Tunnel, macOS-first v1

Revised 2026-07-28 by `TASK-260728-3a2dnr` to encode the owner-approved macOS
prototype strategy (ADR-013 re-scope, ADR-014, ADR-023, ADR-024).

## Objective
Deliver a production, notarized **macOS full-tunnel system VPN** whose external
transport is one or more authenticated SSH connections to a user-controlled
host. To the OS it is a system VPN (`NEPacketTunnelProvider`); on the wire it is
SSH to the user's own machine. Execute the relux-tunnel board's autonomous work
to completion and halt cleanly at the irreducible human gates. iOS is deferred.

## Approved strategy (binding)
- **SSH contract: Option A.** M0 proves *viability*; the four deferred SSH
  semantics are evidence-gated M3 obligations, not waivers (ADR-023).
- **libssh2 is the primary engine.** `ReluxNIOSSH` stays recorded comparative
  evidence and gets no further fork work unless libssh2 is invalidated
  (ADR-014).
- **Gate A0 is not a prototype gate.** Apple-policy/App-Review evidence moves to
  the release and iOS branch (ADR-013). Do not run A0 research on the prototype
  critical path.
- **iOS is deferred.** Physical P0 for this goal is macOS-only, on the current
  Apple-silicon Mac. iOS identifiers stay defined so the work resumes without
  renaming (ADR-024).
- **Linux CI/runner is not required** for the early working-client path. Native
  Linux relay-asset execution evidence moves to the release path
  (`TASK-260715-1c4l9v`).
- **Signing identities are available; notarization custody is not yet done.**
  Relux Works Apple Development and Developer ID Application identities exist in
  the local Keychain. The notarization credential exists only as a mode-0600
  source file, which does **not** satisfy the Keychain-only invariant: a named
  `notarytool` Keychain profile must be stored, verified, and the source file's
  disposition recorded before the notarization path counts as ready
  (ADR-025, `TASK-260728-dveo1o`). Existing profiles lack Network Extension
  entitlements, so tunnel identifiers and profiles still have to be created.

## Definition of done for this goal
The board's gate-free tasks — M0 spike core; M1 TCP/DNS runtime + macOS provider
adapter; M2 relay protocol/UDP/degraded mode; M3 resilience including the four
deferred SSH semantics; macOS self-update; threat model; CI quality gates — are
implemented, unit/integration-tested on the SPM `ReluxTunnelHarness`,
reviewer-accepted, and marked `done` on the board, up to the point where
progress requires Apple provisioning, a signed-provider approval on this Mac, or
a human product decision. At that boundary work stops with evidence attached —
never a workaround.

## Scope
**IN** — everything buildable/testable on this Mac, plus everything unlocked by
the single up-front ceremony: `ReluxTunnelCore`; the public
`AF_UNIX/SOCK_DGRAM` PacketFlow bridge; HEV/lwIP integration; the libssh2
adapter against the Tier-1 viability contract with conformance/rekey tests
against a real SSH host; the wire protocol + codecs; rootless relay logic +
degraded mode; the generated macOS workspace, host, and packet-tunnel targets;
the macOS provider adapter; macOS UI; the self-update pipeline; the threat
model; CI; reproducible relay build.

**OUT** — iOS targets/UI/provider/TestFlight/App Store/App Review; Gate A0
research; a Linux CI runner; and the tuning **selections** that require physical
performance numbers not yet measured.

## Execution model
Board-driven via `task-board` in `/Users/iv/Developer/relux-tunnel`. The
orchestrator plans from the critical path and delegates every task to tracked
background children per `docs/spawn-policy.md` — **Codex `gpt-5.6-sol` at `high`
as primary orchestrator and at `medium` for every producer, rework owner, and
fresh independent reviewer; `max_parallel` 1** (one tracked child at a time). Each task runs producer →
reviewer → rework → accepted `done`;
never stop at `to-review`. Respect dependency links; sequence dependent work.
**After each accepted task: clean worktree, commit inside the policy window,
push to remote, verify local `HEAD` equals origin.**

The current serial wave plan and the Ceremony C1 script live in
`.task-board/.resources/TASK-260728-3a2dnr/`.

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
- Scoping M0 to viability does **not** relax any of the above. A deferred SSH
  semantic must be surfaced as an explicit not-reported/unsupported state with a
  named M3 owner task; fabricating a value fails the adapter.
- Develop the core on the SPM harness **in parallel** with the manual gates
  (ADR-011); do not re-couple core work to A0.
- Numeric/policy values stay evidence gates — do not hardcode a "final" MTU,
  channel window, lane count, or rekey threshold; keep them injectable pending
  physical selection. Verify non-trivial changes by exercising behavior, not
  tests alone.
- Do not force-fit: if a task starts requiring compensating hacks around a
  platform/product constraint, stop and escalate with evidence.

## Stop-the-line — the irreducible human gates
When the critical path reaches one of these, mark the task `blocked` with the
evidence packet (constraint, options, exact human input needed) and surface it.

**Ceremony C1 — the up-front human *permission* node** (this Mac), owned by
exactly one board node, `TASK-260728-q5kjta`. It contains only grants whose
inputs exist before any agent build, so the human is never asked to remain
present through a producer or review cycle: effective prompt-free signing-key
access; authenticated Relux Works Apple Developer portal/team authority;
authorization to create and download the macOS packet-tunnel App IDs,
entitlements, and development profiles; `notarytool store-credentials` into a
**named** Keychain profile plus the source-file disposition decision (ADR-025);
Sparkle EdDSA generation into custody (ADR-026 — generation only). Per ADR-028,
the node may contain honestly recorded resumed owner interactions; this does not
permit an uninterrupted-session claim, invented timestamps, or retrospective
claims about an Always Allow click or a separately timestamped two-factor event.
Its only blocker is the approved identifier matrix `ypo7yo`, so it is reachable
inside the first autonomous segment.

The four evidence tasks it unblocks — `apc34w`, `3jloqy`, `dveo1o`, `ziprhs` —
are **agent** work that runs unattended with the granted access and keeps its
full evidence obligations. Owner decision D1 (`intsjz`) needs no Mac access and
is recorded under the same ceremony node. Never request, echo, or persist secret
values or secret paths.

**Approval A1 — the brief later approval prompt.** `3jloqy` unblocks `1r0fxv`,
which is ordinary agent work that must be produced and independently reviewed.
Only then can macOS show the system-VPN and system-extension approval dialogs
for the disposable probe. A1 is a separate short human interaction on `9yp8to`:
approve the probe, after which the rest of that task runs unattended. Folding
A1 into C1 would mean claiming a human can sit through a producer-reviewer cycle.
For the same reason **sign-off S1** (`2ayxqn` AC5 — the owner acknowledges the
Gate P0 verdict) cannot be pre-granted: the verdict does not exist yet.

**Later gates, in order:**
1. **macOS physical M1 validation (Hold H2)** — approve the system VPN for the
   real app, whose bundle identifier differs from the probe, then run
   lifecycle/routing/DNS-leak evidence (`3f4rhy` → `12x6oq` → `2wqffe`).
2. **Product decisions** — launch locales (`intsjz`, batched into C1), legacy
   SOCKS disposition (`35nc5m`), HEV fork approval (`3mnqn8`), privacy/support
   copy approval (`2gwfaw`). These are owner decisions with no approved default;
   each is a named hold, not a task an agent may decide.
3. **Manual ratification checkpoints** — M1 runtime/routing/trust contracts
   (`1dsqnj`), M3 policy/resilience contracts (`l639qp`), M5 release-governance
   contracts (`2d308k`). Each task's own text says human owners ratify; agent
   drafting and independent agent review complete before the checkpoint.
4. **macOS release ceremonies and sign-offs** — release identity/entitlement/
   migration contract approval (`1tzaed` AC5), Developer ID/notary environment
   completion (`3gkwn0`, which now consumes `dveo1o`), third-party notice legal
   review (`151xf0` AC5), system-extension approval for the Developer ID-signed
   candidate on a clean system (`1r48pc`), the rollback-rehearsal freeze approval
   (`yynqbr`), and the final distribution acceptance run (`2aessv`). The M4
   physical product/security/accessibility matrix (`zwtrhy`) runs unattended on
   this Mac under the H2 approval.
5. **Deferred branch** — Gate A0 evidence (`1i6bh7` → `1828xy`), then iOS
   targets, TestFlight, and App Review. Per ADR-027 these carry `blocked`
   status so no scheduler can pull them onto the prototype path.

The generated plan in `.task-board/.resources/TASK-260728-3a2dnr/` is the
authoritative count. A node that needs human action is never counted as
autonomous, even when agent work follows inside the same node.

## Success signal
All autonomous tasks accepted `done`; the SPM harness and the signed macOS
provider demonstrate the packet bridge, HEV, the libssh2 engine, TCP + leak-free
DNS forwarding, and a relay round-trip end-to-end on this Mac; and the board's
only remaining open items are exactly the human gates above, each with a clear
ask. A human then runs those gates, and the signed, notarized macOS VPN ships
with working in-app self-update.
