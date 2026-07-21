# TASK-260715-27uz4n — Portable relay toolchain evidence

Date: 2026-07-21
Role handoff: developer -> review
Source revision represented by validation builds: `f017796bb88ee31be7d99c57cd6bf58b58728c4e`
`SOURCE_DATE_EPOCH`: `1784646053`

## Delivered contract

- Go 1.26.5 gc and internal linker, official host archive SHA-256 values, Syft 1.48.0, standard-library-only module policy, checkout v7.0.1 commit, four target and CPU baselines, linkage, runtimes, build flags, licenses, and offline environment inputs are pinned in `relay/toolchain-manifest-v1.json`.
- Installed Go provenance compares the complete tree with the retained checksum-pinned archive and rejects changed, missing, added, mode-drifted, linked, duplicate, traversing, device, or unsafe entries.
- Clean and incremental build preparation now uses no-follow type checks for the final workspace root and every HOME/cache child. Symlinks and non-directories fail with exact diagnostics, and every resolved child must remain beneath the resolved target sandbox. Incremental mode preserves only safe target-local state; clean mode recreates the workspace.
- CI pins the approved checkout action, verifies exact missing inputs, offline dependencies, four clean targets, CPU metadata, static Linux and bounded Darwin linkage, licenses, and native Ubuntu 24.04 amd64/arm64 runtime rows without claiming an older Linux kernel floor.

## Verification

- `python3 -m unittest scripts/tests/test_relay_release.py`: 26 tests pass, including both root types, all five symlinked HOME/cache children, non-directory children, resolved containment, clean deletion, incremental reuse, full Go-tree provenance, exact missing inputs, checkout pin, CPU metadata, and linkage negatives.
- `make relay-toolchain-ci RELAY_VERSION=0.1.0 SOURCE_COMMIT=f017796bb88ee31be7d99c57cd6bf58b58728c4e SOURCE_DATE_EPOCH=1784646053`: passes Go tests and vet, exact negatives, all four clean builds, metadata/linkage validation, and license extraction.
- `make relay-shell-validate` with the same immutable inputs: passes two isolated byte-identical four-target relay and protocol-test builds, SBOM, manifest, checksum, notices, verification, native macOS arm64 smoke, and Rosetta amd64 smoke. Linux execution remains correctly delegated to the native CI rows.
- Black, py_compile, JSON parse, shell syntax, ShellCheck, Actionlint, YAML parse, gofmt, privacy scan, git diff check, and task-board validation pass.

## Produced SHA-256

- Toolchain manifest: `5cc01380d548be4c063675075f49e6fb1eb921813723c8683041da64a27ab144`
- Darwin amd64: `f98fd792e56fb4194fb5ea8c781473dfbdfabb790d902b600a6a5902ddbbed65`
- Darwin arm64: `33997626ded267e15a0699e87340edc447992351b5606fd6f8362a23e990bb8f`
- Linux amd64: `40f2f34d5928e7c65a71aeb1cc18e84d857a2a651b7fcfc0d3d049dd4207ce88`
- Linux arm64: `9a0d79f3aa12a638383eca34cc4f276ad784503f87795d7d75184601bbfa6735`
- Go notice: `6421b4e40e376421358fc2c6237ec9672dd77e929e5a13f526f09ce165bfa67b`
