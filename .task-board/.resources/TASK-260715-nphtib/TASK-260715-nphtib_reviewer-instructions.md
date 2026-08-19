# Independent review instructions

Review TASK-260715-nphtib against its complete acceptance criteria and the committed provider-graph contract at revision `7dc73ac6e7325f86a4a178a0558619f0fc9d1490`.

Use independent checks and task-scoped evidence. Pay special attention to `BUG-260819-34ikhl`: one warm-cache `swift test` run timed out in the harness signal-cancellation cleanup test while the authoritative clean matrix, coverage run, and a subsequent `swift package clean && swift test` passed. Decide from evidence whether this violates the task's deterministic-test acceptance boundary. Do not accept merely because a bug was filed; request rework if deterministic acceptance is not proved.

Verify the generated provider's actual adapter/HEV/libssh2 linkage, relay resource integrity, absence of fixture or dynamic-loader linkage, clean generation, legacy preservation, privacy-safe evidence, and the build-only safety boundary.

Never sign, install, launch, save, start, or stop a VPN; never mutate NetworkExtension preferences, routes, or DNS on this development Mac.

If accepted, record the reviewer verdict and leave commit-confirmed terminal movement to the orchestrator. If changes are required, return the task to `to-dev` with exact reproducible findings.
