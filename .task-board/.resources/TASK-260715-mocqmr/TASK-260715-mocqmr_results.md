# TASK-260715-mocqmr rework-01 handoff evidence

Status: ready for fresh independent review as tester handoff.

## Rework delivered

- Added a verified runtime containment boundary to every smoke subprocess. macOS uses `sandbox-exec` to deny filesystem writes, networking, and process forks. Linux uses Landlock to deny filesystem mutation and seccomp to deny sockets and non-thread process creation while allowing Go runtime threads.
- Added a live containment probe that must prove external-write, listener, and descendant-process denial before relay identity execution. Missing or unsupported containment is a red gate.
- Added real adversarial detached/reparented-child and external shared-temporary-write fixtures. Both fail closed, leave no marker or process, and preserve an observed nonzero exit code.
- Made all native/emulated report commands fixed-vocabulary and path-free. Runner metadata, emulator metadata, error codes, check count, argument count, and total report bytes are bounded. Private executable/emulator paths, secret-looking basenames, and oversized metadata are not retained.
- Every subprocess check now records `processStarted` and the observed `exitCode`; identity and stdout-contamination mismatch paths have deterministic failed-check records.
- Updated the four-row workflow test invocation to promote `ResourceWarning` to errors, updated relay documentation, and recorded the independent-review finding and resolution in `LOGBOOK.md` entry 1253.

## Exact rebuilt assets

Command: `make relay-shell-build RELAY_VERSION=0.0.0 SOURCE_COMMIT=ca40fa3da95bb7d04df1862837f729616585ea12 SOURCE_DATE_EPOCH=1787158920` — exit 0.

`make relay-shell-verify` — exit 0.

| Target | Size | SHA-256 |
| --- | ---: | --- |
| darwin/amd64 | 2,623,664 | `b07433c2e625d84549c10a6e84ad72f2ecf29d3e407d4dfcbca5cb73d2da4e36` |
| darwin/arm64 | 2,487,362 | `9eb27fcfd69c9cc0504e89f27db5af8c16faa234db57c23b87ee8efc222d12df` |
| linux/amd64 | 2,592,894 | `96dffe0a1354b6ccd3be951c92e7ffe0334456fa75567f95862678c7f6f29b35` |
| linux/arm64 | 2,556,030 | `11b791db2c900ca2b5ee15326a82b68ac541537b0969bc73090b834fff4672e7` |

Manifest SHA-256: `71448a7fe545fd0b1a484ab1d0d4d02566f22f793bf7797ab87884a862a87362`.

## Native runner evidence

The final native Darwin arm64 gate exited 0 and passed 17/17 checks against the rebuilt asset. It recorded containment probe 0, identity 0, stdio EOF 0, redacted rejection 65, four unsupported invocations 64, and SIGTERM 130. No children, sockets/listeners, runtime files, process residue, or cleanup failure were observed. The 3,335-byte report passed a path/privacy scan and has SHA-256 `0c09bcb79c16e4d904bb06acb789bdf3d250f8a36e6bc0deb10aa772428b1323`.

Twenty consecutive full native gate runs also exited 0 and each retained SIGTERM exit 130. The exact final report replaces the task-scoped `TASK-260715-mocqmr_native-darwin-arm64-report.json` outcome.

The Darwin amd64, Linux amd64, and Linux arm64 native rows are implemented but cannot run on this Darwin arm64 build-only host. They remain mandatory, target-matched GitHub Actions rows with `fail-fast: false`; `--require-native` keeps missing runner support red with owner `TASK-260715-36gq4m`. No remote CI execution is claimed before push.

## Validation with real exit codes

- `python3 -W error::ResourceWarning -m unittest scripts/tests/test_relay_asset_smoke.py -v` — exit 0; 17/17 tests pass.
- Python trace coverage — exit 0; `relay_asset_smoke.py` 81.1%, tests 97.8%.
- Detached descendant/external write, target/architecture/hash/size/symlink/zero/non-executable, stdout/stderr, unsupported mode, listener/child observer, cleanup, root/emulation truth, report-bound, and exit-code mutations — all rejected as expected within the 17-test suite.
- `python3 -m py_compile ...` — exit 0.
- `black --check ...` — exit 0.
- `actionlint -color` — exit 0.
- `make relay-shell-test relay-shell-vet` — exit 0; all Go packages, 35 release-tool tests, and Go vet pass.
- `make relay-supply-chain-audit relay-toolchain-check` — exit 0.
- `make relay-shell-build ...` and `make relay-shell-verify` — exit 0.
- Final native Darwin arm64 gate — exit 0; privacy scan exit 0.
- Twenty-run native SIGTERM/cleanup stress — exit 0; 20/20 pass with exit 130.
- `git diff --check` — exit 0.
- `task-board validate` — process exit 0 but reports the existing ancestor `PARENT_STATUS_MISMATCH` for `EPIC-260715-2lz67t` (`to-dev` versus child aggregate `development`); this is not represented as clean board health and is outside this leaf task's code scope.

The build host safety contract was preserved: no signing, app/provider launch, VPN preference, `startVPNTunnel`, route/interface/pf/DNS mutation, remote traffic, or physical-device action was performed.
