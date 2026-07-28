# TASK-260728-1glezz — autonomous serial agent policy

Role: developer (implementer). Status: ready for review.
Toolchain: `task-board version 0.23.0 (commit beec6e9, built 2026-07-27T23:36:53Z)`.

## What changed

| File | Change |
|---|---|
| `task-board.config.json` | `agent_context.profile: lite`; `spawn.preferred_agentic_system.mixed: [claude, codex]`; `spawn.launch_composition.enabled: true`; Claude ceiling `claude-fable-5` → `claude-opus-5`; `session_manager.providers.codex.auto_continue`; `version_control.confirm` + `desired_commit_time` |
| `docs/spawn-policy.md` | Rewritten to the serial Codex-orchestrator / Claude-producer / Codex-reviewer model; added review routing, commit+sync policy, context/autonomy, runtime ignores, effective-policy verification commands |
| `README.md` | Spawn-policy pointer updated to the new roles |
| `.spec/goal-macos-v1.md` | Execution model line de-Fabled; commit/push wording aligned to the window policy |
| `.gitignore` | Ignore `.task-board/.progress-pair-generation`, `.task-board/.progress-pair-journal.json` |

Not changed: any tunnel product implementation; any Git identity or signing setting.

## AC verification (effective config, not file contents)

`project_config(view=spawn-preflight, ...)` is the authority — the config file is only input.

**1. Producer preflight — `role=developer, agent=claude`** (exit 0)
```json
{"agent_context":{"profile":"lite","source":"config"},"enabled":true,
 "launch_composition":{"enabled":true,"status":"enabled"},"max_parallel":1,
 "providers":{"allowed":["claude","codex"],"target":"claude"},
 "resolved_role_ceiling":{"config_key":"spawn.ceilings.claude","configured":true,
   "model":"claude-opus-5","model_criterion":"equal"},
 "role":"developer","selection_mode":"explicit_override"}
```

**2. Reviewer preflight — `role=reviewer, agent=codex`** (exit 0)
```json
{"agent_context":{"profile":"lite","source":"config"},"enabled":true,
 "launch_composition":{"enabled":true,"status":"enabled"},"max_parallel":1,
 "providers":{"allowed":["claude","codex"],"target":"codex"},
 "resolved_role_ceiling":{"config_key":"spawn.ceilings.codex","configured":true,
   "model":"gpt-5.6-sol","model_criterion":"equal","reasoning_effort":"high"},
 "role":"reviewer","selection_mode":"explicit_override"}
```

**3. Provider restriction enforced** — `role=developer, agent=qwen` (exit 1)
```
agent_not_allowed_by_preferred_agentic_system: spawn.preferred_agentic_system:
provider "qwen" is not allowed; allowed providers: claude, codex
```
Refusal happens in preflight, before task lookup or launch side effects.

**4. Serial capacity** — `max_parallel: 1` in both preflights and in `project_config()`.
Documented as workdir-local: it does not coordinate a second worktree or client.

**5. Lite context** — `agent_context.profile: lite`, `source: config` (not a CLI
override). Effective prompt shape from `project_config()`:
`role=contract`, `dod=deduplicated`, `safety=compact`, `skills=catalog`,
`cli_reference=task-specific`, `preconditions={mode: budgeted, inline_bytes: 2048}`;
responses `spawn=compact`, `observation=terminal-delta`, `selection=delta-only`.

**6. Bounded Codex auto-continue** — from `project_config()`:
```json
"session_manager":{"providers":{"codex":{"auto_continue":{
  "config_key":"session_manager.providers.codex.auto_continue",
  "enabled":true,"delay_seconds":20,"max_nudges_per_turn":2,
  "legacy_read":"codex.session.auto_continue","prompt":"Continue autonomously unless
  blocked by a real ambiguity, approval boundary, or missing external input. …"}}}}
```
Bounded at 2 nudges/turn; the prompt preserves ambiguity/approval/external-input gates.

**7. Commit policy recorded exactly** — `version_control.desired_commit_time`
resolves with all six required elements: 20:00–09:00 Europe/Moscow (21:00–10:00
Asia/Tbilisi) window; Asia/Tbilisi `+04:00` timestamp offset; strictly monotonic
in accepted-task order; ≥ one-minute interval between consecutive commits; push
after every accepted task; verify local `HEAD` equals origin. Mirrored as a
numbered procedure in `docs/spawn-policy.md`. `version_control.confirm: true`
resolves with `commit_ack=scope_committed`, `enforced_types=[bug, story]`.

**8. Git identity and signing unchanged**
```
$ git config --local --get-regexp '^(user\.|commit\.gpgsign|gpg\.|tag\.gpgsign)'
(no matches — no local overrides introduced)

effective: Ivan Oparin <ivan@relux.works> sign=true fmt=ssh key=~/.ssh/ivan_relux_signing
```

**9. Superseded policy removed** — scans over `docs/`, `README.md`, `.spec/`, `.planning/`:

| Pattern | Result |
|---|---|
| `fable` | clean |
| `claude-only\|claude only\|never codex` | clean |
| `out of credits\|usage limit\|top up\|restore credits` | clean |

The pre-existing `docs/spawn-policy.md` sections "History", "Security-testing
tasks -> Claude", and "Temporary: Codex out of credits -> claude-fable executor
(2026-07-20)" are deleted. The last surviving Fable reference was
`.spec/goal-macos-v1.md:35`, now corrected.

Note: `credit` still appears in `.research/260720_*` relay-protocol documents.
Those are flow-control/queue-admission credit — unrelated to the agent-credits
fallback policy, and `.research/` is not a canonical policy doc. Left untouched.

**10. Model registry sanity** — both pinned models are registered and the pinned
effort is supported: `claude-opus-5` (agent=claude, recommended) and
`gpt-5.6-sol` (agent=codex, `supportedEfforts` includes `high`).

**11. Config and diff checks**
```
python3 -m json.tool task-board.config.json  → OK (valid JSON)
git diff --name-only  → .gitignore, .spec/goal-macos-v1.md, LOGBOOK.md,
                        README.md, docs/spawn-policy.md,
                        task-board.config.json,
                        .task-board/…/TASK-260715-1gjxer/progress.md
out-of-scope file check → clean
grep execution_policy task-board.config.json → no match
```

**12. Spawn continuity not enabled** — `spawn.execution_policy` is absent from
the config. `docs/spawn-policy.md` records the prohibition: it stays out until
the continuity branch is independently audited, rebased, released, and proven
against real provider resume paths.

## Notes for the reviewer

- `task-board validate` reports 47 pre-existing board-structure issues
  (one `CYCLE_DETECTED` among three M-epics, plus `PARENT_STATUS_MISMATCH` on 16
  stories). All predate this task, none involve `task-board.config.json`, and
  fixing them is outside this scope. Flagging rather than silently absorbing.
- `.task-board/…/TASK-260715-1gjxer/progress.md` shows in `git diff`. That is a
  task-board runtime write (Last Update bump + a precondition-resource link from
  an earlier task), not a hand edit. Board files were not edited directly.
- `.task-board/.progress-pair-journal.json` does not exist on disk yet; the
  ignore entry is prospective and `git check-ignore -v` confirms both rules
  resolve (`.gitignore:12`, `.gitignore:13`).
- The orchestrator model cannot be enforced by board config — it is a
  primary-session launch property. `docs/spawn-policy.md` states this explicitly
  so the Sol-orchestrator row is not mistaken for an enforced ceiling.
- Nothing is committed. Commits await the policy window and human review.

## Open risk raised by this change (needs a decision, not a silent fix)

The deleted section "Security-testing tasks -> Claude" documented a real
provider behaviour, not a stale preference: Codex `gpt-5.6-sol` was observed
tripping OpenAI's cybersecurity content filter on legitimate defensive
security-testing work (fuzzing, adversarial/hostile-input corpora, DNS/route
leak tests, redaction tests) and exiting non-zero mid-run.

The new policy makes review Codex-owned and marks exactly those areas
(security, networking, DNS, parsers, signing, release) as `review=required`.
So the highest-risk tasks are now routed to the provider that previously failed
on them. Removing the section was required by the AC and I did not re-add a
contradicting rule, but the underlying constraint is not resolved by this task.

Options, if it reproduces:
1. Route reviewer to `--agent claude --model claude-opus-5` for security-testing
   tasks only, and record it as a scoped exception in the review-routing section.
2. Keep Codex review and treat a filter exit as a retryable infrastructure
   failure with a Claude fallback reviewer.
3. Accept as-is if the filter behaviour no longer reproduces on `gpt-5.6-sol`.

Recommendation: option 1, scoped narrowly to security-testing tasks — it keeps
review independent from the Claude producer only if the reviewer is a separate
Claude instance, which spawn already guarantees. This is a policy decision for
the orchestrator/owner, so it is flagged here rather than implemented.
