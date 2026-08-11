# TASK-260715-39xz9g SSH matrix orchestration v1

This is the executable companion to
`TASK-260715-39xz9g_ssh-matrix-fixture-manifest-v1.json`. It defines how later
candidate matrix tasks resolve the controlled servers without putting a host,
user, private-key path, credential, or private material in git or a report.

## Reproduction

Validate the public manifest, orchestration registry, endpoint implementations,
impairment path, lifecycle behavior, and report redaction:

```bash
make ssh-fixtures-test
make ssh-fixtures-lifecycle
python3 scripts/ssh_matrix_fixture.py orchestration-preflight
```

`ssh_matrix_provider.py` is the checked-in provider for current/fallback macOS,
the no-mount task-owned Ubuntu Lima VM, and the approved `ssh-config://relux`
identity. Its lifecycle command performs prepare, exact rotation policy,
least-privilege reachability, scenario control, and zero-residual teardown for
all four rows. Transient private keys, accounts, routes, ports, PIDs, and SSH
configuration stay under `.temp/TASK-260715-39xz9g/provider-state/` or the
approved external SSH/Lima stores and are removed by teardown.

An approved operator configures the two candidate-driver environment variables.
Their values and any credentials resolved through the provider runtime remain in
the external operator environment:

- `RELUX_SSH_MATRIX_LIBSSH2_DRIVER`
- `RELUX_SSH_MATRIX_RELUXNIOSSH_DRIVER`

The three provider variables remain optional overrides for controlled
environments; when absent, orchestration uses the checked-in provider:

- `RELUX_SSH_MATRIX_MACOS_PROVIDER`
- `RELUX_SSH_MATRIX_LINUX_PROVIDER`
- `RELUX_SSH_MATRIX_RELUX_PROVIDER`

Then run the identical candidate matrix:

```bash
python3 scripts/ssh_matrix_fixture.py orchestrate \
  --output .temp/TASK-260715-39xz9g/matrix-report.json
```

The orchestrator requires both candidate IDs to observe every scenario. The
success scenario runs against all four server rows. Destructive negative cases
use only task-owned macOS fixtures; they never change the real relux host. The
latency and loss rows receive a numeric-loopback TCP proxy as their SSH endpoint,
so impairment is applied to the connection actually exercised by the driver.

## Provider protocol

The orchestrator invokes each provider command with one canonical JSON object
on stdin and expects one JSON object on stdout. Stderr is always redacted on
failure.

The request protocol is `relux-ssh-matrix-provider-v1`. Actions are:

- `prepare`: provision a task-owned server or resolve an owner-managed one,
  start the six task-owned destination listeners on that SSH server, and make
  the stdio commands available; return `status: ok` and an in-memory `runtime`
  containing `host`, `port`, `identityReference`, and the complete numeric-IPv4
  `destinationEndpoints` map.
- `rotate`: rotate a task-owned fixture credential, or report
  `external-owner-managed` for the approved real-host identity; return
  `status: ok`, `disposition`, and optionally a replacement `runtime`.
- `control`: deterministically instantiate the requested negative, rekey, or
  endpoint condition and return its exact finite `fixtureEvidenceCode` plus any
  scenario-specific in-memory runtime. Host-key change and rejected-auth
  controls are restricted to task-owned macOS fixtures.
- `probe`: prove non-root reachability after rotation. Return `status: ok` and
  exactly the public observation fields accepted by the orchestrator:
  `architecture`, `hostKeyFingerprints`, `opensshVersion`, `osName`,
  `osVersion`, `privilege`, `reachable`, and `userKeyTypes`.
- `teardown`: remove only task-owned processes, listeners, VM state, ephemeral
  credentials, and known-hosts state. Return `status: ok` and
  `residualResources: 0`.

Providers resolve the manifest's `ephemeral-memory://`, `lima-store://`, and
`ssh-config://` references. Runtime descriptors may contain sensitive routing
and identity data because they travel only in process memory. They are never
copied into the matrix report.

## Candidate-driver protocol

Each driver receives protocol `relux-ssh-matrix-driver-v1` with the candidate,
server, and scenario IDs, the in-memory server runtime, the effective SSH
endpoint, all direct-tcpip destination addresses, the selected network profile,
and these public long-lived exec commands:

```text
python3 -u scripts/ssh_matrix_fixture.py stdio-echo
python3 -u scripts/ssh_matrix_fixture.py stdio-sink
```

Providers launch each direct-tcpip destination with
`python3 -u scripts/ssh_matrix_fixture.py serve-endpoint --mode <mode>` and
read its first stdout line for the numeric-loopback address. The modes are
`echo`, `sink`, `early-close`, `half-close`, `reset`, and `disconnect`.

The driver returns only `status: pass`, the matching `scenarioId`, and the exact
finite public `observationCode` registered for that scenario. Free-form text,
including a code with a valid-looking scenario prefix, is rejected. A missing
provider control, declaration-only row, skipped row, missing candidate, or
malformed result fails closed and prevents report creation.

## Teardown and privacy

Provider teardown runs in reverse preparation order even when provisioning,
probing, or a candidate row fails. The endpoint set and all impairment proxies
are task-owned numeric-loopback listeners and are stopped on every path. A
successful report records public observations, matrix outcomes, rotation
dispositions, zero-residual teardown evidence, and `payloadRetention: none`.
It excludes every runtime descriptor and is scanned for private-key and
password markers before output.

Linux teardown enumerates the task-named Lima instance, fails closed on list or
delete errors and timeouts, and enumerates again after deletion. The provider
retains its task state for a safe cleanup retry until absence is positively
confirmed; only then can it report zero residual resources.

Credential rotation for the real relux identity remains owner-managed: this
fixture proves the external reference and least-privilege access but does not
mutate a non-task-owned account. Task-owned macOS/Linux providers must return
`rotated` after replacing their ephemeral identity.
