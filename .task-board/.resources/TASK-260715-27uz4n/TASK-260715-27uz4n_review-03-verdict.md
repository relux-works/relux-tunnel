# TASK-260715-27uz4n — Review 03 verdict

Date: 2026-07-21
Verdict: accepted → done

## Isolation rework

Fresh reproduction passed. A symlinked sandbox root fails in clean mode, incremental mode, and direct `sanitized_environment` use with exact `build sandbox root must not be a symbolic link`. A regular-file root fails all paths with exact `build sandbox root must be a directory`, and clean mode leaves its content untouched. HOME, TMPDIR, GOCACHE, GOMODCACHE, and GOPATH each reject a symlink and a regular-file replacement with the exact variable-specific diagnostic; GOPATH also rejected a FIFO as a non-directory. Direct child resolution outside the canonical root fails with exact `build sandbox HOME escapes build sandbox root`. An escaping parent symlink is canonicalized and rejected before traversal. Legitimate incremental reuse preserved its target-local cache marker; clean mode removed it and recreated a normal root.

Code inspection confirms the create race is fail-closed: if a missing path appears between initial lstat and mkdir, the FileExists path is followed by another no-follow stat. The final root and each direct environment child are no-follow type checked, then resolved and containment checked before their canonical paths enter the environment. Existing parent components are resolved before the `.build/relay` boundary test, so a parent symlink cannot hide an external root. As with the rest of the checkout/toolchain, this does not claim protection against a malicious process running as the same user mutating paths after validation; no cross-user writable component or deterministic parent-component escape was found.

## Original five findings

1. Freshly provisioned the retained official Go 1.26.5 Darwin arm64 archive into `.build/relay/review03-go`; checksum and whole-tree comparison passed. Real `go/src/runtime/proc.go` and `go/src/archive/tar/common.go` content tampering failed with exact content diagnostics. Deleted, added, mode, directory-type, symlink, and hardlink drift also failed exactly. Independent archive fixtures rejected duplicate and traversing paths, symlink, hardlink, FIFO, device, set-id permissions, missing parents, absolute paths, and backslashes.
2. `test-relay-toolchain-missing-input.sh` used actual HEAD `f017796bb88ee31be7d99c57cd6bf58b58728c4e` and passed the exact missing-Go and missing-SOURCE_DATE_EPOCH diagnostics.
3. No Linux 4.4 or older-kernel claim remains. Manifest, docs, and workflow declare only native unprivileged Ubuntu 24.04 amd64 and arm64 fixtures. The macOS host rejected the Linux-native smoke with the exact host-boundary diagnostic; local Linux execution is not claimed. GitHub documentation confirms both workflow labels.
4. Every checkout use and the manifest equal `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1`; upstream `refs/tags/v7.0.1` resolves to that commit, and the drift negative passed.
5. All four produced executables report exact GOOS, GOARCH, CGO_ENABLED=0, trimpath, and only the architecture-appropriate GOAMD64=v1 or GOARM64=v8.0. A real GOAMD64=v3 binary and a cross-architecture verification were rejected with the exact metadata diagnostic.

## Full gates

- 26 Python tests pass.
- `make relay-toolchain-ci` passes with pinned Go 1.26.5, actual HEAD/epoch, offline test/vet, exact negatives, four clean target builds, metadata/linkage, and license extraction.
- `make relay-shell-validate` passes: two isolated four-target relay and protocol-test builds compare byte-for-byte; provenance, SPDX 2.3 SBOMs, checksums, notices, manifest verification, macOS arm64 native smoke, and Rosetta amd64 smoke pass.
- Linux outputs are static little-endian ELF64 without PT_INTERP/PT_DYNAMIC; Darwin outputs load exactly libSystem and libresolv and carry platform macOS, minos 12.0, sdk 12.0.
- Produced target SHA-256 values independently match the producer evidence: Darwin amd64 f98fd792e56fb4194fb5ea8c781473dfbdfabb790d902b600a6a5902ddbbed65; Darwin arm64 33997626ded267e15a0699e87340edc447992351b5606fd6f8362a23e990bb8f; Linux amd64 40f2f34d5928e7c65a71aeb1cc18e84d857a2a651b7fcfc0d3d049dd4207ce88; Linux arm64 9a0d79f3aa12a638383eca34cc4f276ad784503f87795d7d75184601bbfa6735.
- Black, py_compile, shell syntax, ShellCheck, Actionlint, Ruby YAML parse, gofmt, git diff check, targeted credential/privacy scan, and task-board validation pass.
- Live primary-source checks match all four Go archive SHA-256 values from go.dev, all four Syft 1.48.0 archive hashes, peeled Syft tag commit 3e2bc6ed095f7ec1a415fb38cfe1c319e95dfed6, checkout v7.0.1 commit 3d3c42e5aac5ba805825da76410c181273ba90b1, and GitHub-hosted Ubuntu 24.04 x64/arm64 labels.

All acceptance criteria and prior review findings are satisfied. The implementation fits the repository build architecture and preserves the honest host-runtime evidence boundary.