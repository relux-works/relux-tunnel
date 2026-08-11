# TASK-260715-39xz9g — reviewer verdict, round 4

Verdict: changes requested; route to to-dev.

## Acceptance-blocking finding

Partial provider preparation can still produce false zero-residual teardown evidence. scripts/ssh_matrix_provider.py starts and tracks the endpoint supervisor at lines 286-306, but _prepare persists state only after the complete server prepare returns at lines 255-265. _teardown terminates processes only when that state file exists at lines 727-744.

A bounded injected diagnostic forced macOS sshd preparation to fail after the endpoint supervisor started. The diagnostic exited 0 and observed trackedProcessCount=1, stateExistsAfterFailure=false, aliveBeforeTeardown=1, teardown status=ok with residualResources=0, and aliveAfterZeroResidualTeardown=1. The diagnostic then explicitly terminated the task-owned process; a follow-up scan exited 0 with TASK_ENDPOINT_WORKERS_AFTER_DIAGNOSTIC=0. This violates the cleanup and teardown-truth contract even though the happy path is green.

Required rework: persist cleanup ownership before each resource is spawned or make teardown reconcile durable and in-memory partial resources; ensure partial prepare failures for macOS, Linux, and the real-host endpoint cannot report zero while owned processes, VM state, keys, or listeners remain; add regression tests that inject failures after each provisioning boundary and prove cleanup continues across all prepared rows.

## Independent passing evidence

- make ssh-fixtures-test: exit 0; 39 tests passed.
- swift test: exit 0; 428 tests in 35 suites passed.
- strict recursive Swift format lint: exit 0. Python compilation, manifest validation, manifest JSON parsing, and git diff check: exit 0. Tab scan: exit 1 with no matches, treated as clean.
- Unit and integration trace: exit 0; ssh_matrix_fixture.py line coverage 84.0 percent. Fresh traced four-server lifecycle: exit 0; ssh_matrix_provider.py line coverage 90.8 percent.
- Fresh lifecycle reached Linux current, macOS current, approved fallback, and real relux rows as non-root; privacy scan found no forbidden field, provider state entries were 0, and the named Lima instance count was 0.
- Fresh streamed 5 GiB source and sink: exit 0; 5368709120 bytes and SHA256:fc01cfd7aebf90ff9491f8556131b6ef575c3e1fa33a0277ba28920bbaee7f54 with no retained payload.
- Attached and repository manifest SHA-256 values both equal 2036df17599554d203a446658f188216ee6c3c933976072728a1fd22df106225.
- task-board validate exited 0 while reporting the existing parent aggregate mismatch during reviewing; routing this leaf to to-dev aligns the parent aggregate.

## Architecture assessment

The manifest, provider, candidate-driver protocol, Makefile gates, and fixture tests otherwise follow the project structure and provide a focused deployment topology without requiring an additional diagram. The remaining defect is an ownership-lifecycle mismatch between resource creation and persisted teardown state, so it is implementation rework rather than a Stop-The-Line decision.