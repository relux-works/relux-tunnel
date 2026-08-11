# TASK-260715-39xz9g reviewer verdict

Verdict: changes requested.

## Acceptance findings

1. AC1/AC2 are not reproducible from the checked-in artifacts. The manifest lists four server rows and says they are verified, but its reproduction commands only validate the manifest, run two local Swift test filters, and stream local traffic. There is no checked-in provisioning, reachability, rotation, or teardown command for the Linux fixture or the real relux identity. The only executable SSH server harness is the macOS-local LoopbackSSHD test fixture.
2. AC3 and the task scope are incomplete. scripts/ssh_matrix_fixture.py exposes only verify-manifest, traffic-hash, traffic-source, and traffic-sink. serve_endpoint is unit-tested through socket.socketpair, apply_latency only sleeps, and deterministic_drop_indexes only returns ordinal numbers. No listener/runner connects these helpers to direct-tcpip, no impairment is applied to an SSH path, and no identical M0 matrix is executed against the server rows or both candidates.
3. The scoped long-lived stdio exec echo/sink fixture is absent. Existing Swift coverage uses one-shot printf/sleep/cat commands in a local loopback sshd; the new tool only implements local stdin/stdout traffic and socket helpers.
4. AC4 and AC5 are supported: the deterministic 5 GiB source/sink contract has a pinned count/hash with no retained payload, and inspected artifacts contain public fingerprints, non-secret configuration, and external secret-reference names rather than private credentials.

## Independent gates

- make ssh-fixtures-test: exit 0; 16 tests passed.
- swift test --filter LibSSH2AdapterIntegrationTests: exit 0; 26 tests passed.
- swift test: exit 0; 428 tests in 35 suites passed.
- swift format lint --strict Tests/ReluxTunnelLibSSH2AdapterTests/LibSSH2AdapterIntegrationTests.swift: exit 0.
- python3 -m py_compile scripts/ssh_matrix_fixture.py scripts/tests/test_ssh_matrix_fixture.py: exit 0.
- git diff --check: exit 0.
- task-board validate: exit 0, but reported PARENT_STATUS_MISMATCH for STORY-260715-lkshfz (stored backlog versus child aggregate reviewing).

## Required rework

Add a privacy-safe executable orchestration path that provisions or resolves each server row, starts the direct-tcpip and long-lived stdio fixtures, applies latency/loss to the exercised path, runs every required scenario identically against both candidates (including Linux and the approved real-host identity), records observed results rather than accepting hard-coded reachability, and performs scoped rotation/teardown. Add integration tests or retained task-scoped run evidence proving that orchestration path. Preserve external-only secrets and public-only artifacts.