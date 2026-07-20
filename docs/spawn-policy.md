# Spawn policy — relux-tunnel

Two-tier execution: a **Claude/Fable orchestrator** delegates to a **Codex/Sol
executor**. The per-agent models are pinned in `task-board.config.json` via spawn
ceilings (`model_criterion: equal`), so an explicit spawn request is coerced to
the configured model even if mis-specified.

## Roles → models

| Role | Agent | Model | Effort | Set by |
|---|---|---|---|---|
| Orchestrator (this session) | claude | `claude-fable-5` | max | `/model` (session, not board config) |
| Executor #1 | codex | `gpt-5.6-sol` | `high` | `spawn.ceilings.codex` |
| Any Claude spawn (sub-orchestrator / reviewer) | claude | `claude-fable-5` | — | `spawn.ceilings.claude` |

Notes:
- The orchestrator is the primary session, **not** a spawned child, so its model
  (`claude-fable-5`) and effort (`max`) are set with `/model`, not the board
  config. The `claude` ceiling only governs spawned Claude children.
- Claude spawns do not accept a reasoning-effort flag (`claude_reasoning_effort_supported: false`).
- Codex spawns require an effort; the ceiling pins it to `high` for `gpt-5.6-sol`.

## Canonical spawn commands

```bash
# executor (developer / tester) — Codex Sol high
task-board spawn TASK-… --role developer --background --agent codex --model gpt-5.6-sol --reasoning-effort high

# reviewer — independent Codex Sol review (or --agent claude for a Fable review)
task-board spawn TASK-… --role reviewer --background --agent codex --model gpt-5.6-sol --reasoning-effort high

# sub-orchestrator / decomposition — Claude Fable
task-board spawn TASK-… --role solution-architect --background --agent claude --model claude-fable-5
```

## Config (`task-board.config.json`)

```json
"spawn": {
  "enabled": true,
  "max_parallel": 1,
  "ceilings": {
    "codex":  { "model": "gpt-5.6-sol",   "model_criterion": "equal", "reasoning_effort": "high" },
    "claude": { "model": "claude-fable-5", "model_criterion": "equal" }
  }
}
```

`max_parallel: 1` means a single tracked background executor runs at a time
(orchestrator session + one executor); further spawns queue and start as the slot
frees. `model_criterion: equal` coerces any spawn on that agent to the configured
model; it cannot allowlist two models or disable an agent (only
`spawn.enabled: false` is a global kill). To change a tier, edit the ceiling and
redeploy.

## History

Superseded the earlier Claude-only (fable/opus, no Codex) policy: the executor
tier is now Codex `gpt-5.6-sol` at `high`, orchestration stays on Fable.

## Security-testing tasks -> Claude

Codex (`gpt-5.6-sol`) trips OpenAI's cybersecurity content filter on legitimate
defensive security-testing tasks (fuzzing, adversarial/hostile-input corpora,
exploit-adjacent, leak tests) and exits non-zero mid-run. Route these to
`--agent claude --model claude-fable-5` instead (authorized defensive context).
Examples: packet/protocol/UDP fuzz + allocation-bounds, DNS/route leak tests,
security/redaction tests. Everyday non-security executor work stays on codex-sol.
