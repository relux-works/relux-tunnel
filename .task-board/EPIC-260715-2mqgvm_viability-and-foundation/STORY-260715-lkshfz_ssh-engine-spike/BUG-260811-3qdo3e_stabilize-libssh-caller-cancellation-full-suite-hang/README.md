# BUG-260811-3qdo3e: stabilize-libssh-caller-cancellation-full-suite-hang

## Description
The real-sshd Swift Testing case caller cancellation is scoped and idle reads have no implicit timeout hangs intermittently during repeated unfiltered swift test runs, after the HEV UDP suite has already passed. It blocked BUG-260728-2j25tu after a 12-run clean aggregate streak and reproduced in three independent attempts.

## Scope
In scope: reproduce and remove the deterministic lifecycle/resource cause of the LibSSH cancellation hang; preserve the current uncommitted TASK-260715-1u2vpc algorithm-matrix changes; verify cancellation remains scoped and idle reads retain no implicit timeout. Out of scope: weakening or skipping the test, adding sleeps/timeouts only to hide the hang, changing SSH security policy, or discarding current task-board work.

## Acceptance Criteria
1. The exact test completes deterministically under repeated execution and still proves scoped cancellation plus no implicit idle timeout. 2. No sleep-only, skip, or wall-clock masking workaround is used. 3. At least twenty consecutive unfiltered swift test runs complete successfully with 426 or more tests. 4. Task-scoped evidence records reproduction, root cause, before/after behavior, resource cleanup, and retained TASK-260715-1u2vpc changes.
