# Spawn policy — relux-tunnel

Serial single-provider execution: a **Codex/Sol primary orchestrator** delegates
implementation and independent review to tracked **Codex/Sol** children.
`max_parallel: 1` permits one tracked child at a time in this workdir. The model
and effort are pinned in `task-board.config.json` with `model_criterion: equal`.

## Roles → models

| Role | Agent | Model | Effort | Set by |
|---|---|---|---|---|
| Orchestrator (primary session) | codex | `gpt-5.6-sol` | `high` | primary-session launch |
| Producer / implementer | codex | `gpt-5.6-sol` | `high` | `spawn.ceilings.codex` |
| Independent reviewer | codex | `gpt-5.6-sol` | `high` | `spawn.ceilings.codex` |

Notes:
- The orchestrator is the primary session, **not** a spawned child. Its Sol
  model is selected when launching or resuming the primary session; spawn
  ceilings cannot enforce the primary model.
- Codex spawns require an effort; the ceiling pins every role to `high` for `gpt-5.6-sol`.
- Explicit provider policy permits only Codex; Claude, Gemini, Muse, and Qwen are out of policy.
- `agent_context.profile: lite` keeps task contracts and safety gates while
  removing repeated generic context and materializing large preconditions.

## Canonical spawn commands

```bash
# producer (developer / tester / researcher) — Codex Sol high
task-board spawn TASK-… --role developer --background --agent codex --model gpt-5.6-sol --reasoning-effort high

# reviewer — independent Codex Sol high
task-board spawn TASK-… --role reviewer --background --agent codex --model gpt-5.6-sol --reasoning-effort high

# architecture producer — Codex Sol high
task-board spawn TASK-… --role solution-architect --background --agent codex --model gpt-5.6-sol --reasoning-effort high
```

## Config (`task-board.config.json`)

```json
"agent_context": { "profile": "lite" },
"spawn": {
  "enabled": true,
  "max_parallel": 1,
  "preferred_agentic_system": { "exclusive": "codex" },
  "launch_composition": { "enabled": true },
  "ceilings": {
    "codex":  { "model": "gpt-5.6-sol", "model_criterion": "equal", "reasoning_effort": "high" }
  }
},
"session_manager": {
  "providers": {
    "codex": {
      "auto_continue": { "enabled": true, "delay_seconds": 20, "max_nudges_per_turn": 2, "prompt": "…" }
    }
  }
},
"version_control": { "confirm": true, "desired_commit_time": "…" }
```

Verify the effective policy — the config file is input, these views are truth:

```bash
task-board q 'project_config(view=spawn-preflight, role=developer, agent=codex)'
task-board q 'project_config(view=spawn-preflight, role=reviewer, agent=codex)'
task-board q 'project_config()'
```

`max_parallel: 1` means a single tracked background executor runs at a time
(orchestrator session + one executor); further spawns queue and start as the slot
frees. This limit is local to the workdir and does not coordinate a second
worktree or client. `model_criterion: equal` coerces an in-policy provider spawn
to its configured model.

## Review routing

- Security, networking, concurrency, DNS, parsers, signing, update, and release
  tasks use `review=required`.
- Low-risk documentation, deterministic code generation, and board maintenance
  may use `review=light`.
- `review=none` is reserved for deterministic evidence wiring where the
  orchestrator can verify every acceptance criterion mechanically.
- Rework remains producer-owned; review uses a fresh independent Codex run.

## Commit and synchronization policy

After every accepted task:

1. Commit the accepted task scope.
2. Use a commit timestamp inside **20:00-09:00 Europe/Moscow**, equivalent to
   **21:00-10:00 Asia/Tbilisi**.
3. Record timestamps using the Tbilisi `+04:00` offset. Synthetic future
   timestamps are allowed.
4. Preserve accepted-task order: every timestamp must be strictly later than
   the previous commit, with at least a one-minute interval.
5. Push and verify local `HEAD` equals the remote branch.

The repository's current Git identity and signing configuration remain in
force; task-board does not replace them. `version_control.confirm: true` keeps
the commit acknowledgement gate on, scoped to the agent's own work
(`commit_ack=scope_committed`); foreign uncommitted work does not block a
handoff.

Task-board writes local runtime state under `.task-board/` that is not board
content and must stay untracked:

```gitignore
.task-board/.progress-pair-generation
.task-board/.progress-pair-journal.json
```

## Context and autonomy

`agent_context.profile: lite` is enabled. Codex primary-session
`auto_continue` is enabled with two bounded nudges per turn. It does not bypass
real ambiguity, approval, secret, platform, or external-input gates.

Persistent producer/reviewer continuity is not part of task-board `0.23.0`.
Do not add `spawn.execution_policy` until the continuity branch is independently
audited, rebased, released, and proven against real provider resume paths.

## Build-host VPN prohibition

All agent roles treat this development Mac as build-only. Spawns may run local
builds, compilation, lint, unit/integration tests, harnesses, simulators, archive
inspection, and unsigned provider tests. They must not install or open a VPN
app/system extension, persist a NetworkExtension preference, start or activate
a tunnel/provider, or mutate routes or DNS on this host.

Any macOS physical VPN validation task must depend on the human provisioning
gate `TASK-260819-25e1ys`. It executes only on the configured dedicated Mac and
must first pass `scripts/physical-test-host-preflight.sh`; neither agent
autonomy nor a spawned role may bypass that guard. The authoritative operation
matrix and fail-closed identity contract are in
[`build-host-safety.md`](build-host-safety.md).
