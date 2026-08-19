# TASK-260715-1q03sa reproducibility results

Date: 2026-08-19
Role: tester
Verdict: PASS — ready for independent review
Scope: unsigned, unnotarized relay executables and build-only bundle inputs

## Result

Two independent temporary clones with separate clean cache/output roots produced byte-identical results for all four declared targets. The exact 11-file release tree, four protocol-test executables, and normalized four-member archive match. No irreducible variance remains and no semantic-identity exception is used.

The pre-fix proof found uncontrolled Syft drift. Executable and protocol-test bytes already matched, but every SPDX document differed at exactly `$.creationInfo.created` and `$.documentNamespace`; the first raw difference in the inspected Darwin arm64 SPDX file was byte offset 188 (zero-based). This cascaded into different manifest and checksum bytes. The fix derives the SPDX creation time from `SOURCE_DATE_EPOCH`, derives the namespace from the executable name plus exact SHA-256, recursively sorts SPDX JSON keys, and compares every declared file rather than executable bytes alone.

## Runner and input identity

- Runner A/B: separate local clones and separate build/cache/output roots on `darwin/arm64`, macOS 26.5 build 25F71, Darwin 25.5.0. Temporary clone roots were deleted after copying evidence outputs.
- Source commit: `e8bd954a1985e0a3204504209f1b022f71e4d1f9`
- Repository tree: `d29c4d09f302633786fa984c8ef651fbb41fb1b8`
- Relay tree: `4f52531c3a84bd059fb5be4893f4ed22115cb818`
- Relay `git ls-tree` aggregate SHA-256: `1f20e83e69e0053a220b9fc3cb0926e39427bc85cb9501a550f5e7447de9473b`
- `relay/go.mod` SHA-256: `bd56300ba5f8e2263128ac97c6852ea42770644808a14d54a04113f23200deb6`
- Reproducibility recipe SHA-256: `10051c52c85e7a43d03362aa8ee4dbe1b6954410c258c801b7e1dd483532b2de`
- Toolchain manifest SHA-256: `5cc01380d548be4c063675075f49e6fb1eb921813723c8683041da64a27ab144`
- Go: `go1.26.5 darwin/arm64`; executable SHA-256 `3925fc3221ac440ebf7c35361ff663bed0c7bdb2e0a157b75fe993607ffe0a19`; archive SHA-256 `efb87ff28af9a188d0536ef5d42e63dd52ba8263cd7344a993cc48dd11dedb6a`
- Syft: `1.48.0`, commit `3e2bc6ed095f7ec1a415fb38cfe1c319e95dfed6`, `darwin/arm64`; executable SHA-256 `dbecffadfefbf3095e992195e592cd9a5f7232a9cb3ec6019cb1b6a9afe2a185`; archive SHA-256 `fef3e6d5df336a0a4c3e421e503119d1e221cf82a3ef5e426a791fcd81667e87`
- Relay version: `0.0.0`; `SOURCE_DATE_EPOCH=1787158980`; `LC_ALL=C`; `LANG=C`; `TZ=UTC`; `PYTHONHASHSEED` is irrelevant after recursively sorted SPDX serialization.
- Build policy: `GOTOOLCHAIN=local`, `CGO_ENABLED=0`, `GOENV=off`, `GOWORK=off`, `GOPROXY=off`, `GOSUMDB=off`, `GOVCS=off`, isolated `HOME/TMPDIR/GOCACHE/GOMODCACHE/GOPATH`.
- Linker/compiler policy: `-mod=readonly -trimpath -buildvcs=false -tags=netgo,osusergo`, internal linker, `-s -w -buildid=`, fixed version/commit injection. Paths, build IDs, and debug symbols therefore cannot vary runtime bytes.

The pinned source checkout predates this task. Both clones received the same explicitly declared recipe overlay above; relay source remained the exact pinned Git tree. No untracked or shared-worktree input entered either build.

## Byte comparison

| Artifact | Bytes | SHA-256 in both runs |
| --- | ---: | --- |
| `relux-relay-darwin-amd64` | 2,623,664 | `80b5480b4e3fb792c353317e499bb0a242f9d0bf9fd9bb9ff6a2b854fdaa5166` |
| `relux-relay-darwin-arm64` | 2,487,362 | `3190d2cdb15f18157bdd1a83f4990e107f42d981faa50f4c678b10fc6f9be55e` |
| `relux-relay-linux-amd64` | 2,592,894 | `2a11104908941cec8b18934c9bf6874558fa03e8195589a427c2585e740474c4` |
| `relux-relay-linux-arm64` | 2,556,030 | `3b9d5bba5511b799738ee25f4168ea7eb474111458c128d55c434654ab8f07a6` |
| Darwin amd64 SPDX | 6,089 | `41ce29288f18739796f9ae39886a24ba9356fdf94d9aeec26aefb98e00ce3e78` |
| Darwin arm64 SPDX | 6,089 | `cb21c9007896c10480ab62d229e30ffb73cb56c917ad7d5dc0cdea070c871240` |
| Linux amd64 SPDX | 6,076 | `2bcc9778a2c5eba668da5da8407ee0449776c833d7f10ecb78edbb7044ca58c2` |
| Linux arm64 SPDX | 6,076 | `d26ae0dc704340739e3da7aa72335b2095f7ce4205df3ea1edf72165d89d8811` |
| Four-entry manifest | 1,978 | `ef5bd8b3cc41ce0e30c026bd088b370faeea30d789a7c6708631330afe8b049d` |
| SHA-256 checksum file | 965 | `c7b328892d75c1f87544987348a223cc5a346644da4cf26fce2f490ea0cd89ec` |
| Notices | 2,756 | `6421b4e40e376421358fc2c6237ec9672dd77e929e5a13f526f09ce165bfa67b` |
| Protocol test Darwin amd64 | 2,386,640 | `19ee8eeda39435b17405ce50f678c59e60023307bbd4728064d29ec8518c3836` |
| Protocol test Darwin arm64 | 2,265,010 | `16a76f19e9bb82bd529b8169685873c0b2066e8f1944292527fb4fd3d4d28a72` |
| Protocol test Linux amd64 | 2,248,830 | `dcad73bb5dba2d2011da17eea913583ca9d987929a0adee8b5511989a6b44624` |
| Protocol test Linux arm64 | 2,162,814 | `0c9421a69bde2edcd8c54adde50c17f6a790b690444d9935adb2fc699fbf3fc0` |

Comparator result: `identical=15/15`. It validates the exact file/directory set, rejects symlinks and unsupported entries, compares file modes and SHA-256, and reports semantic JSON paths plus first raw byte offset, sizes, and hashes on drift.

Normalized archive result: both archives SHA-256 `09014b22e694b1ff4ab664c81d46b3afccd5a973f701cbd4625bfd88c093ab40`. Member order is Darwin amd64, Darwin arm64, Linux amd64, Linux arm64; each is regular mode 0755, uid/gid 0, root/root, integer mtime `1787158980`, and has no PAX headers. Filesystem mtimes outside this normalized archive are explicitly not semantic identity; checksum generation always hashes exact bundled bytes.

## Manifest mutation proof

A copied Linux/amd64 executable was changed by one byte; canonical accepted output was never edited.

- Baseline manifest SHA-256: `ef5bd8b3cc41ce0e30c026bd088b370faeea30d789a7c6708631330afe8b049d`
- Mutated manifest SHA-256, render 1 and render 2: `ba7db4548bd3c974bf6651fc4e9686a4267d2874c74123df6c5af6a09da89579`
- Repeated mutated renders identical: true
- Manifest changed from baseline: true
- Only changed target identity: `linux/amd64`
- Canonical executable unchanged after proof: true

## Exact reproduction commands

Run from repository root. These commands resolve paths locally but do not record them in evidence:

```bash
REPO=$(pwd -P)
GO="$REPO/.build/relay/toolchains/go1.26.5-darwin-arm64/go/bin/go"
SYFT="$REPO/.build/relay/toolchains/syft1.48.0-darwin-arm64/syft"
COMMIT=e8bd954a1985e0a3204504209f1b022f71e4d1f9
EPOCH=1787158980
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/relux-repro.XXXXXX")
mkdir -p "$REPO/.build/relay/TASK-260715-1q03sa"
EVIDENCE_ROOT=$(mktemp -d "$REPO/.build/relay/TASK-260715-1q03sa/repro.XXXXXX")

for RUN in run-a run-b; do
  git clone --quiet --no-local --no-hardlinks --no-checkout "$REPO" "$SCRATCH/$RUN"
  git -C "$SCRATCH/$RUN" checkout --quiet --detach "$COMMIT"
  cp "$REPO/scripts/relay_release.py" "$SCRATCH/$RUN/scripts/relay_release.py"
  python3 "$SCRATCH/$RUN/scripts/relay_release.py" build \
    --go "$GO" --go-toolchain local --syft "$SYFT" \
    --relay-version 0.0.0 --source-commit "$COMMIT" \
    --source-date-epoch "$EPOCH" --require-provenance \
    --output .build/relay/TASK-260715-1q03sa/release \
    --test-output .build/relay/TASK-260715-1q03sa/protocol-tests
  mkdir -p "$EVIDENCE_ROOT/$RUN"
  cp -R "$SCRATCH/$RUN/.build/relay/TASK-260715-1q03sa/release" \
    "$EVIDENCE_ROOT/$RUN/release"
  cp -R "$SCRATCH/$RUN/.build/relay/TASK-260715-1q03sa/protocol-tests" \
    "$EVIDENCE_ROOT/$RUN/protocol-tests"
done

python3 scripts/relay_release.py compare \
  --first "$EVIDENCE_ROOT/run-a/release" \
  --second "$EVIDENCE_ROOT/run-b/release" \
  --first-tests "$EVIDENCE_ROOT/run-a/protocol-tests" \
  --second-tests "$EVIDENCE_ROOT/run-b/protocol-tests"
```

The proof copied each run's output to the task-scoped paths used by the comparator, then deleted both temporary clone trees with `find "$SCRATCH" -depth -delete`.

## Validation and exit codes

- Independent build A: exit 0.
- Independent build B: exit 0.
- Full 15-file comparator: exit 0, `identical=15/15`.
- Per-run release verification during each build: exit 0.
- Normalized archive generation and `cmp`: exit 0.
- `make relay-shell-reproducibility RELAY_VERSION=0.0.0 SOURCE_COMMIT=$COMMIT SOURCE_DATE_EPOCH=$EPOCH`: exit 0, `identical=15/15`.
- `make relay-shell-test relay-shell-vet relay-toolchain-check relay-supply-chain-audit`: exit 0; all Go packages passed, 43 Python tests passed, Go vet passed, toolchain check passed, supply-chain audit passed.
- Python trace coverage command: exit 0; changed functions 154/162 executable lines, 95.1%. Whole pre-existing release tool: 70.2%; test module: 98.5%.
- `black --check scripts/relay_release.py scripts/tests/test_relay_release.py`: exit 0.
- `python3 -m py_compile ...`: exit 0.
- `git diff --check`: exit 0.
- `task-board validate`: process exit 0, with one reported pre-existing ancestor diagnostic: `EPIC-260715-2lz67t` is stored `backlog` while its child aggregate is `development`. The leaf task and its resources are valid; this diagnostic is not hidden or reported as a clean board-wide result.

Non-gate diagnostics: the optional third-party `coverage` module was unavailable (exit 1), so the dependency-free standard-library trace command above was used. An initial trace attempt used the wrong short option and exited 1 before tests; the corrected command exited 0.

## Residual variance and safety

Residual unexplained or permitted byte variance: none. Signing identities, notarization tickets, installed copies, and runtime performance are out of scope and were not used as semantic identity. The proof was offline and rootless; it did not sign, notarize, install, configure, save, enable, or start an app/provider/VPN, call `startVPNTunnel`, or mutate routes, interfaces, packet filters, or DNS.
