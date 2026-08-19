# TASK-260715-mocqmr rework-01 independent review verdict

Verdict: **accepted**. The implementation satisfies the five acceptance criteria and closes all three prior blocking findings without weakening the original runtime-boundary contract.

## Blocking-finding closure

1. **Detached descendants and external writes:** Fresh real fixtures attempted `start_new_session` daemonization/reparenting and a write beside the isolated runtime root. The macOS containment boundary denied both operations. Each gate failed closed with an observed exit `1`, `processStarted=true`, no marker, and no surviving process. The live containment probe also independently proved file-write, listener, and process-creation denial before every native relay invocation.
2. **Path-free bounded evidence:** Native, emulated, private-path, oversized-metadata, and oversized-report cases passed. Retained commands use fixed semantic vocabulary; executable/emulator paths and arbitrary arguments are absent. The final native report is 3,339 bytes (limit 32,768), parses as canonical JSON, and the privacy scan found no host/private path or payload marker.
3. **Observed exit preservation:** Fresh failure reproductions recorded identity mismatch exit `0`, timeout termination exit `-9`, and detached/external-write fixture exit `1`, all with `processStarted=true`. A true pre-start launch failure recorded `processStarted=false` and `exitCode=null`, which is the only permitted null case. The successful signal path records exit `130`.

## Independent validation and exact exit codes

- `python3 -W error::ResourceWarning -m unittest scripts/tests/test_relay_asset_smoke.py -v` — exit `0`; 17/17 tests passed.
- `python3 -m trace --count --missing --summary --coverdir ... --module unittest scripts/tests/test_relay_asset_smoke.py` — exit `0`; affected `relay_asset_smoke.py` coverage `81.1%`.
- Python compilation, `black --check`, `actionlint -color`, and `git diff --check` — each exit `0`.
- `make relay-shell-test relay-shell-vet` — exit `0`; all relay Go packages, 35 release-tool tests, and Go vet passed.
- `make relay-supply-chain-audit relay-supply-chain-test relay-toolchain-check relay-toolchain-negative-test` — exit `0`; 21 supply-chain tests and missing-input gates passed.
- Fresh `make relay-shell-build ...` and `make relay-shell-verify` — each exit `0`; the pinned Go 1.26.5/Syft 1.48.0 provenance and exact four-asset manifest verified.
- `make relay-shell-reproducibility ...` — exit `0`; all four relay and protocol-test executable byte comparisons passed.
- `make relay-shell-smoke ...` — exit `0`; Darwin arm64 native passed, Darwin amd64 was explicitly additional Rosetta evidence only, and both Linux targets remained explicitly delegated to their required native CI rows.
- Fresh final Darwin arm64 runtime gate — exit `0`; 17/17 checks passed, including containment `0`, identity `0`, EOF/stdout framing `0`, redacted rejection `65`, unsupported modes `64`, SIGTERM `130`, and cleanup.
- Twenty additional full native gates — aggregate exit `0`; 20/20 reports passed, each with 17 checks and signal exit `130`.
- Reviewer adversarial packet SHA-256: `e9d87f869d447cf474e2b1e5d74b7af48eda8ff23dc6057f9d56920d376d286c`.
- Final native report SHA-256: `25230e1fad798bf0ab3833edbe862b5a82f89db3ae8d83008bd47d0b20e2e303`.

## Exact gated executable identities

| Target | Size (bytes) | SHA-256 |
| --- | ---: | --- |
| darwin/amd64 | 2,623,664 | `b07433c2e625d84549c10a6e84ad72f2ecf29d3e407d4dfcbca5cb73d2da4e36` |
| darwin/arm64 | 2,487,362 | `9eb27fcfd69c9cc0504e89f27db5af8c16faa234db57c23b87ee8efc222d12df` |
| linux/amd64 | 2,592,894 | `96dffe0a1354b6ccd3be951c92e7ffe0334456fa75567f95862678c7f6f29b35` |
| linux/arm64 | 2,556,030 | `11b791db2c900ca2b5ee15326a82b68ac541537b0969bc73090b834fff4672e7` |

The final fresh manifest used by the native gate has SHA-256 `1a2de7cc599ae4eac812555a913ef523b89998e664cf2ee8a1d72c669134b402` and binds protocol version 1, build identity, exact sizes, executable hashes, and per-target SBOM hashes.

## CI and architecture fit

- The workflow has exactly four target-matched native rows, `fail-fast: false`, pinned checkout action and checksum-pinned Go/Syft archives, offline release build, `--require-native`, per-row evidence, and exact asset/SBOM/manifest/checksum retention for 14 days.
- Current official GitHub runner documentation confirms `macos-15-intel` is Intel, `macos-15` is arm64, `ubuntu-24.04` is x64, and `ubuntu-24.04-arm` is arm64: https://docs.github.com/en/actions/reference/runners/github-hosted-runners and https://github.com/actions/runner-images/blob/main/README.md.
- Darwin containment was exercised natively. Linux Landlock/seccomp construction was reviewed against the syscall layout: the empty Landlock ruleset handles mutation rights, the filter denies sockets and non-thread clone/fork/vfork/clone3 while allowing `CLONE_THREAD`, and unavailable primitives fail before identity execution. The two Linux implementations become authoritative only on their mandatory native rows.
- No remote CI execution is claimed before push. The other three native reports are required outputs of the red-gated matrix; cross-build and Rosetta evidence do not satisfy them.
- `LOGBOOK.md` entries 1252 and 1253 preserve the signal-race and escaped-descendant/external-write findings and resolutions.
- Build-host safety was preserved: no signing, app/provider installation or launch, VPN preferences, `startVPNTunnel`, route/interface/pf/DNS mutation, remote traffic, or physical-device action.

`task-board validate` returned process exit `0` while reporting the existing ancestor status diagnostic `PARENT_STATUS_MISMATCH` for `EPIC-260715-2lz67t` during the active review state. This is recorded honestly and is not a leaf implementation defect.

Acceptance evidence is ready for the commit-owning mover. This reviewer did not stage, commit, or supply `commit_ack`.
