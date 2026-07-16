# Project management

Relux Proxy uses the private
[`relux-works/skill-project-management`](https://github.com/relux-works/skill-project-management)
tooling. The board is stored locally in `.task-board/` and committed with the
repository. Saved execution plans live in `.planning/`.

## Workstation setup

Clone or update the skill source, then run its canonical setup command:

```sh
git clone git@github.com:relux-works/skill-project-management.git \
  ~/src/skill-project-management

cd ~/src/skill-project-management
./scripts/setup.sh \
  --project-dir /path/to/relux-proxy \
  --mode local \
  --board-dir .task-board \
  --bootstrap-local-agents
```

The command installs `task-board`, registers the project-management skill, and
creates the repo-local agent runtime. `.agents/`, `.claude/`, `.codex/`, and
`.local/` are generated machine-local directories and are intentionally ignored.

Verify the setup from the repository root:

```sh
agents-infra doctor local "$PWD"
task-board q --format compact 'project_config(); summary()'
task-board validate
```

## Planning contract

- Product and architecture requirements are source-controlled under `.spec/`.
- Epics, stories, tasks, dependencies, and acceptance criteria are managed only
  through `task-board`; never edit `.task-board/` files by hand.
- A story is implementation-ready only after it has atomic child tasks with
  verifiable acceptance criteria and explicit dependencies.
- Canonical phases come from `task-board q 'plan(...)'`; saved snapshots are
  generated with `task-board plan ... --save`.
- Implementation requires explicit user approval of the saved plan. The current
  planning effort does not authorize implementation.
