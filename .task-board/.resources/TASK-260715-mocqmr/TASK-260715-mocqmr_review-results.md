# TASK-260715-mocqmr independent review verdict

Verdict: changes requested; route to `to-dev`.

## Blocking findings

1. **Detached descendants and writes outside the fixture root pass the gate.**
   `signal_smoke` samples only direct children of the relay PID, and after exit
   checks only that PID. `exercise_runtime` scans only its private
   `runtime_root`. A bounded reviewer fixture started a fully detached,
   reparented Python sleeper and wrote a marker under `/tmp` during the
   supported stdio signal path. The complete gate returned success while the
   external marker existed and escaped PID `62395` remained alive:

   `gate_result=PASS escaped_pids=[62395] outside_file=True`

   The reviewer killed PID 62395 and deleted the temporary marker immediately
   after observation. This violates AC 2 and AC 3: the gate does not prove no
   child/process residue or system-path writes. Relevant implementation:
   `scripts/relay_asset_smoke.py` lines 441-466 and 563-581. The existing tests
   inject direct-child/socket observer results and create files only below the
   monitored root, so they do not cover this escape.

2. **Emulated evidence is not path-free.** `safe_command` strips only argv[0].
   With an emulator, the executable is a later argv entry and its absolute host
   path is retained; `runner.name` and emulator arguments are also copied
   without validation or bounds. Reviewer reproduction returned:

   `path_leaked=True runner_name='/Users/reviewer/private/build/path' command=['arch','-x86_64','/Users/reviewer/private/build/path','/tmp/relay','--identity']`

   This violates AC 5 and the required privacy-safe/path-free evidence
   contract. Relevant implementation: `scripts/relay_asset_smoke.py` lines
   68-71, 265-275, and 278-296.

3. **Failure evidence drops observed exit codes.** On stdout contamination the
   process exit was observed, but `expect_process` records a failed check
   without passing `exit_code`. Reviewer reproduction produced:

   `{"errorCode":"stdio-eof-and-stdout-framing_contract_mismatch","failedChecks":[{"exitCode":null,"name":"stdio-eof-and-stdout-framing","status":"fail"}]}`

   Identity failures can similarly leave no identity check record. This
   violates AC 5's requirement to record commands, durations, hashes, exit
   codes, and privacy-safe failures. Relevant implementation:
   `scripts/relay_asset_smoke.py` lines 388-402 and 496-515.

## Independent positive evidence

- Preconditions matched the supplied SHA-256 digests.
- `python3 -W error::ResourceWarning -m unittest scripts/tests/test_relay_asset_smoke.py -v`: exit 0, 13/13 pass.
- Python trace coverage: exit 0; `relay_asset_smoke.py` 85.2%, tests 97.0%.
- `python3 -m py_compile ...`: exit 0.
- `actionlint -color`: exit 0, no diagnostics.
- `git diff --check`: exit 0.
- `make relay-shell-test relay-shell-vet`: exit 0; relay Go tests, 35 release-tool tests, and vet pass.
- `make relay-supply-chain-audit relay-toolchain-check`: exit 0.
- Native Darwin arm64 gate stress: exit 0; 12/12 passes against SHA-256
  `9eb27fcfd69c9cc0504e89f27db5af8c16faa234db57c23b87ee8efc222d12df`,
  and every SIGTERM check recorded exit 130.
- Current GitHub documentation confirms `macos-15-intel`, `macos-15`,
  `ubuntu-24.04`, and `ubuntu-24.04-arm` are valid native labels for the four
  matrix architectures. The workflow uses `fail-fast: false`, pinned checkout
  and tool hashes, target-matched native execution, and per-row retention.
- `task-board validate`: process exit 0 but reported the existing ancestor
  `PARENT_STATUS_MISMATCH` for `EPIC-260715-2lz67t`; this is not treated as a
  passing board-health result.

## Required rework

- Make descendant/process-group and external filesystem residue observable and
  fail closed across every runtime subprocess, including detached/reparented
  behavior; add real adversarial regression fixtures rather than only mocked
  observer returns.
- Define and enforce a path-free, bounded report schema for native and emulated
  commands and runner metadata.
- Preserve actual exit codes and a deterministic failed-check record for every
  subprocess failure path.
- Record the escaped-residue finding in `LOGBOOK.md`, rerun all gates, and
  attach revised evidence for fresh independent review.
