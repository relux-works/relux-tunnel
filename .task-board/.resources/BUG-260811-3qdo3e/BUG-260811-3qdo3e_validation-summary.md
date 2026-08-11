# BUG-260811-3qdo3e validation summary

- Focused exact cancellation: 30 consecutive runs, all exit 0.
- Positive automatic keepalive during long rekey: exit 0.
- Fatal automatic keepalive teardown regression: exit 0 and zero owned resources.
- LibSSH real-sshd integration suite: 25 tests, exit 0.
- Final-tree unfiltered Swift suite: 20 consecutive reset-on-any-failure runs, 427 tests in 35 suites per run, all exit 0.
- Final gate run duration range: 17-19 seconds.
- sshd listeners before/after: unchanged PIDs 1330 and 34815; no validation-owned listener leaked.
- Build and checks: `make validate-core`, `make validate-libssh2`, Swift format lint, and `git diff --check` all exit 0.
- Preserved dirty scope: TASK-260715-1u2vpc approved-algorithm matrix remains present.
- Discarded attempts are retained: one unrelated fake-clock counter assertion and one pre-existing write-vs-EOF test race; neither was counted in the final streak or changed in this bug.
