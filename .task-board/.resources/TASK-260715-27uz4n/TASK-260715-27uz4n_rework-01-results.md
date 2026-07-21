# TASK-260715-27uz4n — Portable relay toolchain rework evidence

Date: 2026-07-21
Role handoff: developer → review
Source revision represented by validation builds: `f017796bb88ee31be7d99c57cd6bf58b58728c4e`
`SOURCE_DATE_EPOCH`: `1784646053`

## Rework delivered

- Full installed-Go-tree provenance now compares the checksum-pinned archive
  against every extracted directory and regular file, including exact path set,
  type, permission mode, and file SHA-256. It rejects missing, added, changed,
  duplicate, path-traversing, symlink, hardlink, device, special, and otherwise
  unsafe entries before a release build can use the tree.
- Exact negative fixtures cover changed Go runtime and standard-library sources,
  deleted/added paths, mode drift, installed symlinks, archive duplicates,
  traversal, archive symlinks/devices, missing Go, and missing
  `SOURCE_DATE_EPOCH`. Missing-input commands use the actual checkout `HEAD` and
  compare the complete stderr diagnostic.
- `go version -m` verification now parses exact build settings and enforces
  `GOAMD64=v1` or `GOARM64=v8.0`, including per-target negative fixtures.
- Every workflow checkout is pinned to approved actions/checkout v7.0.1 commit
  `3d3c42e5aac5ba805825da76410c181273ba90b1`. The manifest records the version,
  commit, and release source, and `toolchain-check` requires exact equality with
  every workflow reference.
- The unsupported Linux 4.4 claim was removed. The manifest makes no older
  kernel claim and instead declares native unprivileged Ubuntu 24.04 x86_64 and
  arm64 fixtures. CI runs amd64 smoke in the four-target job and adds a native
  `ubuntu-24.04-arm` arm64 build/smoke job. GitHub's runner reference is recorded
  as the label authority.
- `scripts/tests/test-relay-portable-native.sh` rejects root execution, selects
  only the native Linux artifact, executes it under an environment allowlist,
  and validates its exact smoke JSON.

## Verification evidence

- `python3 -m unittest scripts/tests/test_relay_release.py` — 20/20 pass.
- `make relay-toolchain-ci RELAY_VERSION=0.1.0 SOURCE_COMMIT=f017796bb88ee31be7d99c57cd6bf58b58728c4e SOURCE_DATE_EPOCH=1784646053` — pass:
  whole-tree provenance, exact negatives, all Go packages, `go vet`, four clean
  target builds, binary/linkage/CPU metadata, and license extraction.
- `make relay-shell-validate RELAY_VERSION=0.1.0 SOURCE_COMMIT=f017796bb88ee31be7d99c57cd6bf58b58728c4e SOURCE_DATE_EPOCH=1784646053` — pass:
  two isolated four-target builds are byte-identical; manifest, SBOM, checksum,
  notice, linkage, and smoke verification pass. macOS arm64 executes natively and
  amd64 under Rosetta. Linux is correctly reported unexecuted on this macOS host;
  the workflow contains the two native Linux evidence rows.
- Fresh offline provisioning from the checksum-pinned official Go archive into
  `.build/relay/TASK-260715-27uz4n/fresh-provisioned-go` — pass; reported
  `go version go1.26.5 darwin/arm64`.
- Real full Go-tree negatives reproduced against the reviewer's provisioned copy:
  exact failures for `go/src/archive/tar/common.go` and
  `go/src/runtime/proc.go` content mismatch. The new check also discovered and
  rejected three real workstation-added `.DS_Store` files in the installed tree;
  after removing those generated contaminants, the clean official tree passed.
- Incremental mode retained a target-workspace sentinel; the following clean
  build removed it, proving reuse/deletion remains scoped to the isolated target
  workspace.
- `black --check`, `python3 -m py_compile`, JSON parse, `sh -n`, ShellCheck over
  all relay test scripts, Actionlint, Ruby YAML parse, privacy scan,
  `git diff --check`, and `task-board validate` — pass. Ruby emitted an unrelated
  local `ffi-1.15.0` extension warning before successfully parsing the workflow.

## Produced hashes

| Artifact | SHA-256 |
| --- | --- |
| `relay/toolchain-manifest-v1.json` | `aaf16d9d26644d1554cdaa4876728f8247f7848bdf1e05bcc1ab961e86e411c2` |
| `relux-relay-darwin-amd64` | `f98fd792e56fb4194fb5ea8c781473dfbdfabb790d902b600a6a5902ddbbed65` |
| `relux-relay-darwin-arm64` | `33997626ded267e15a0699e87340edc447992351b5606fd6f8362a23e990bb8f` |
| `relux-relay-linux-amd64` | `40f2f34d5928e7c65a71aeb1cc18e84d857a2a651b7fcfc0d3d049dd4207ce88` |
| `relux-relay-linux-arm64` | `9a0d79f3aa12a638383eca34cc4f276ad784503f87795d7d75184601bbfa6735` |
| Combined MIT/Go BSD-3-Clause notice | `6421b4e40e376421358fc2c6237ec9672dd77e929e5a13f526f09ce165bfa67b` |

## Runtime evidence boundary

The two Linux native rows are enforced workflow fixtures but cannot execute on
this macOS workstation. This handoff therefore claims local build/linkage and
macOS execution evidence plus source/actionlint validation of the Linux jobs,
not a locally observed Linux runtime pass. CI must execute both native jobs for
the corresponding runtime evidence.

Sources:

- GitHub-hosted runner labels: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- actions/checkout v7.0.1: https://github.com/actions/checkout/releases/tag/v7.0.1
