# Exercise CI trust boundaries and release failure paths

## Description
Perform an adversarial end-to-end verification of pull-request and release workflows against the approved trust model, including secret isolation, artifact integrity, cancellation, concurrency, and recovery.

## Scope
In scope: fork and same-repository pull requests, malicious workflow and action-pin fixtures, permission escalation attempts, cache and artifact substitution, tag races, duplicate dispatch, missing and expired credentials, log injection, cancellation at each stage, runner loss, partial upload, rerun, evidence integrity, and recovery. Out of scope: real secret exfiltration, destructive production publication, product feature testing, and replacing platform distribution acceptance.

## Acceptance Criteria
1. A safe test repository, dry-run mode, or equivalent harness executes every documented threat and failure scenario without exposing real production credentials or publishing a public release. 2. Forks and untrusted changes cannot access protected environments, secrets, write tokens, privileged runners, or release artifacts beyond approved read scope. 3. Cache, artifact, tag, and rerun attacks cannot substitute bytes or candidate identity after verification. 4. Cancellation, timeout, runner loss, missing credential, scanner failure, and partial upload leave no falsely successful check or promotable mixed release and have an explicit recovery state. 5. A TASK-ID-scoped report maps each scenario to evidence, observed permissions, logs, artifacts, pass or fail, residual risk, and required remediation.
