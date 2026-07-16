# Spawn policy — relux-tunnel

Board execution on this project uses **Claude only**, restricted to two models.
`task-board.config.json` cannot express this exactly (see "Why not in config"),
so this document is the authoritative policy and MUST be honored by any
orchestrator (human or agent) that spawns board work.

## The rule

- **Agent:** `claude` only. **Never** spawn `--agent codex`.
- **Models:** exactly one of
  - `claude-fable-5` — hardest / longest-running child tasks;
  - `claude-opus-4-8` — everyday complex work (default choice).
- **Never** use `claude-sonnet-5`, `claude-haiku-4-5`, or any Codex model.
- Reasoning-effort flags are Codex-only and MUST NOT be passed to Claude spawns.

## Canonical spawn commands

```bash
# everyday complex task
task-board spawn TASK-… --role developer --background --agent claude --model claude-opus-4-8

# hardest / longest-running task
task-board spawn TASK-… --role developer --background --agent claude --model claude-fable-5

# reviewer (same model rule)
task-board spawn TASK-… --role reviewer  --background --agent claude --model claude-opus-4-8
```

## Why not in config

`task-board` spawn ceilings (`spawn.ceilings.<agent>.model_criterion`) can only
**pin exactly one model per agent** via `equal` (it coerces a request to that
one model); the ordered criteria `less_or_equal` / `greater_or_equal` are
declared but fail closed. There is **no** primitive to allow a two-model set,
and **no** per-agent disable — the only hard switch is `spawn.enabled: false`,
which would also kill Claude spawns.

Therefore:

- `spawn.enabled: true` is kept (Claude spawns must work).
- No `ceilings` are set, so both `claude-fable-5` and `claude-opus-4-8` remain
  selectable.
- "Claude-only, these two models, no Codex/Sonnet/Haiku" is enforced by this
  policy and by orchestrator discipline, not by a config hard-block.

If a future `task-board` adds a model allowlist or a per-agent enable flag,
migrate this rule into `task-board.config.json` and shrink this doc to a pointer.
