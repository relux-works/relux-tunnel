# Relay asset release, update, audit, and rollback runbook

This is the build-host procedure for the four unsigned `relux-relay`
executables. It covers pinning, rebuilding, auditing, bundling, updating, and
rolling back the relay asset set. It does not publish a standalone relay
download, troubleshoot an end-user SSH host, sign or notarize anything, or
authorize an application release.

The relay executables are **not standalone signed downloads**. The signed and
notarized containing application protects the copies bundled in an Apple
product. A copy uploaded through the future SSH bootstrap path remains
untrusted until its exact size and SHA-256 match the locally trusted manifest;
no remote or downloaded executable may run before that verification succeeds.

## Stop conditions

Stop and keep the candidate unreleased if any required command is nonzero, an
expected success token is absent, a target is missing, a native row is not
available, a source/recipe/tool pin cannot be resolved, generated metadata
drifts, or a consumer gate has not run. Do not replace a failed gate with an
emulated result, a locally calculated but unreviewed hash, `--require-clean`
removal, manual manifest editing, or execution of the suspect file.

This Mac is build-only. The commands below are rootless and do not sign,
notarize, install, launch an app or provider, save a VPN preference, call
`startVPNTunnel`, or change routes, interfaces, packet filters, or DNS.

## Authoritative inputs and prerequisites

Run from a full Git checkout with both historical commits available. A shallow
checkout is insufficient.

| Input | Authority | Current accepted value |
| --- | --- | --- |
| Relay source | `relay/supply-chain-source-v1.json` | commit `58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096`, relay version `0.1.0`, epoch `1784656987` |
| Byte-affecting recipe | the same file and `relay/source-build-provenance-v1.json` | commit `4326036a26a515d5d349e669574323d4d1c7259c` |
| Compiler and linker | `relay/toolchain-manifest-v1.json` | official Go `1.26.5`, `GOTOOLCHAIN=local`, internal linker |
| SBOM tool | `relay/toolchain-manifest-v1.json` | Syft `1.48.0`, commit `3e2bc6ed095f7ec1a415fb38cfe1c319e95dfed6` |
| Accepted bytes | `relay/asset-bundle-source-v1.json` | task archive SHA-256 `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e` |
| Protocol | `Protocol/Relay/relay-v1.schema.json` and generated Swift/Go bindings | protocol `1` |
| Manifest | `relay/asset-manifest-v1.schema.json` and `relay/asset-bundle-source-v1.json` | schema `1`, exactly four assets |
| Notices and provenance | `relay/supply-chain-source-v1.json` | generated inventory, provenance, and `relay/PRODUCT_NOTICES.txt` |

Required host tools are Git, Python 3, GNU Make, the platform's ordinary binary
inspection utilities, and the pinned Go and Syft archives. Provisioning is the
only network-permitted tool acquisition step. Build, verification, audit, and
smoke commands are offline.

On a supported macOS build host, provision the checksum-pinned tools with:

```bash
./scripts/bootstrap-relay-tools.sh
make relay-toolchain-check
```

Expected result: both commands exit `0`; bootstrap ends with
`checksum-pinned relay tools are provisioned for <host>`. A missing retained
archive, provenance receipt, unexpected installed-tree entry, checksum drift,
or tool identity mismatch is red. For an offline host, pre-stage the exact
archives named by `relay/toolchain-manifest-v1.json` and use
`make relay-provision-go RELAY_GO_ARCHIVE=...` and
`make relay-provision-syft RELAY_SYFT_ARCHIVE=...`.

Establish path-free working variables and verify the pins before a build:

```bash
set -eu
REPO="$(pwd -P)"
case "$(uname -s)/$(uname -m)" in
  Darwin/arm64) HOST_SLUG=darwin-arm64 ;;
  Darwin/x86_64) HOST_SLUG=darwin-amd64 ;;
  Linux/x86_64) HOST_SLUG=linux-amd64 ;;
  Linux/aarch64) HOST_SLUG=linux-arm64 ;;
  *) echo "unsupported relay build host" >&2; exit 1 ;;
esac
PINNED_GO="$REPO/.build/relay/toolchains/go1.26.5-$HOST_SLUG/go/bin/go"
PINNED_SYFT="$REPO/.build/relay/toolchains/syft1.48.0-$HOST_SLUG/syft"
test -x "$PINNED_GO"
test -x "$PINNED_SYFT"
"$PINNED_GO" version
"$PINNED_SYFT" version
git rev-parse --is-shallow-repository
git cat-file -e 58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096^{commit}
git cat-file -e 4326036a26a515d5d349e669574323d4d1c7259c^{commit}
make relay-supply-chain-audit
```

Expected result: Go reports `go1.26.5`, Syft reports `1.48.0`, the checkout
reports `false`, both `cat-file` commands exit `0`, and the audit ends with
`relay supply-chain audit: pass`.

## Four-target contract

| Go target | Canonical target | CPU baseline | Canonical file | Runtime evidence |
| --- | --- | --- | --- | --- |
| `darwin/amd64` | `x86_64-apple-darwin` | `GOAMD64=v1` | `relux-relay-darwin-amd64` | native unprivileged Intel macOS; minimum OS 12.0 |
| `darwin/arm64` | `aarch64-apple-darwin` | `GOARM64=v8.0` | `relux-relay-darwin-arm64` | native unprivileged Apple silicon macOS; minimum OS 12.0 |
| `linux/amd64` | `x86_64-unknown-linux` | `GOAMD64=v1` | `relux-relay-linux-amd64` | native unprivileged Ubuntu 24.04 x86_64 |
| `linux/arm64` | `aarch64-unknown-linux` | `GOARM64=v8.0` | `relux-relay-linux-arm64` | native unprivileged Ubuntu 24.04 arm64 |

Linux files must be static ELF64 without `PT_INTERP` or `PT_DYNAMIC`. Darwin
files must be Mach-O, carry the declared CPU and macOS 12.0 minimum, and load
only `libSystem.B.dylib` and `libresolv.9.dylib`. A cross-build proves bytes and
headers, not runtime support. No older Linux kernel floor is claimed.

## The two manifest layers

The similarly named manifests have different producers and consumers. Never
substitute one for the other.

| File | Generated and checked by | Retention and use | Bundle/rollback rule |
| --- | --- | --- | --- |
| `relux-relay-manifest-v1.json` | `scripts/relay_release.py build` writes it inside a full release tree; `verify` and `compare` check it | Retain with the 11-file release-builder tree; pass it to `scripts/relay_asset_smoke.py` | It is build evidence and is **not** copied into the application bundle. Roll back to its retained exact bytes; do not regenerate historical raw Syft metadata and call it equivalent. |
| `relux-relay-assets-v1.json` | `scripts/relay_asset_manifest.py generate` derives it from `relay/asset-bundle-source-v1.json`, the schema, and the retained four-member archive; `check` independently regenerates the expected value in memory | Retain with the accepted source contract and archive; Swift consumes the generated catalog derived from it | This is the only manifest bundled beside the four executables under `relay-assets-v1/`. Rollback regenerates it twice from the known-good contract/archive and requires exact equality. |

## Rebuild the currently accepted bytes and manifest

The accepted source and recipe are deliberately split pins. The source commit
predates the final recipe. Therefore a historical rebuild must first verify a
clean source checkout, then overlay only `Makefile`,
`scripts/relay_release.py`, and `relay/toolchain-manifest-v1.json` from the
pinned recipe commit. The combined tree is intentionally not Git-clean, so this
path uses `--require-provenance` through the target builder and separately
proves that compiled source did not change. Do not describe it as a
`--require-clean` build.

### 1. Obtain the retained known-good archive

```bash
mkdir -p "$REPO/.temp/relay-known-good"
task-board resource get \
  TASK-260715-24icoz \
  TASK-260715-24icoz_portable-relay-assets.tar.gz \
  --output "$REPO/.temp/relay-known-good/portable-relay-assets.tar.gz"
printf '%s  %s\n' \
  1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e \
  "$REPO/.temp/relay-known-good/portable-relay-assets.tar.gz" \
  | shasum -a 256 --check
```

Expected result: resource retrieval and `shasum` exit `0`, and the latter
prints `OK`. Any mismatch makes the retained copy suspect; do not extract or
execute it.

### 2. Make two independent clean source clones

```bash
SOURCE_COMMIT=58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096
RECIPE_COMMIT=4326036a26a515d5d349e669574323d4d1c7259c
SOURCE_DATE_EPOCH=1784656987
RELAY_VERSION=0.1.0
mkdir -p "$REPO/.temp"
REBUILD_ROOT="$(mktemp -d "$REPO/.temp/relay-rebuild.XXXXXX")"

for RUN_NAME in run-a run-b; do
  RUN="$REBUILD_ROOT/$RUN_NAME"
  git clone --quiet --no-local --no-hardlinks --no-checkout "$REPO" "$RUN"
  git -C "$RUN" checkout --quiet --detach "$SOURCE_COMMIT"
  test -z "$(git -C "$RUN" status --porcelain=v1 --untracked-files=all)"
  git archive "$RECIPE_COMMIT" \
    Makefile scripts/relay_release.py relay/toolchain-manifest-v1.json \
    | tar -x -C "$RUN"
  git -C "$RUN" diff --exit-code "$SOURCE_COMMIT" -- \
    relay/cmd relay/internal relay/go.mod
  python3 "$RUN/scripts/relay_release.py" toolchain-check
done
```

Expected result: every command exits `0`. The compiled source diff is empty.
Only the declared recipe overlay may differ from the detached source checkout.

### 3. Build all four targets in both clones

```bash
for RUN_NAME in run-a run-b; do
  RUN="$REBUILD_ROOT/$RUN_NAME"
  for TARGET_SLUG in darwin-amd64 darwin-arm64 linux-amd64 linux-arm64; do
    TARGET_NAME="${TARGET_SLUG/-//}"
    python3 "$RUN/scripts/relay_release.py" build-target \
      --target "$TARGET_NAME" \
      --go "$PINNED_GO" \
      --go-toolchain local \
      --relay-version "$RELAY_VERSION" \
      --source-commit "$SOURCE_COMMIT" \
      --source-date-epoch "$SOURCE_DATE_EPOCH" \
      --cache-mode clean \
      --work-dir ".build/relay/work/$TARGET_SLUG" \
      --output ".build/relay/portable/$TARGET_SLUG/relux-relay-$TARGET_SLUG"
  done
done
```

Successful target builds are intentionally quiet and exit `0`. The builder
verifies the tool provenance, target name, binary format, linkage, Go build
information, version, commit, and target CPU metadata. Any `relay-release:`
diagnostic is red.

### 4. Normalize, compare, and verify the archive

The historical byte recipe has no `archive-assets` command. Archive
normalization is non-byte-affecting packaging logic and uses the current safe
writer, which creates an invocation-owned temporary file and atomic final
replacement. The final comparison to the retained archive is authoritative.

```bash
for RUN_NAME in run-a run-b; do
  RUN="$REBUILD_ROOT/$RUN_NAME"
  cp "$REPO/scripts/relay_release.py" "$RUN/scripts/relay_archive_current.py"
  python3 "$RUN/scripts/relay_archive_current.py" archive-assets \
    --portable-root .build/relay/portable \
    --archive .build/relay/portable-relay-assets.tar.gz \
    --source-date-epoch "$SOURCE_DATE_EPOCH"
done

cmp "$REBUILD_ROOT/run-a/.build/relay/portable-relay-assets.tar.gz" \
    "$REBUILD_ROOT/run-b/.build/relay/portable-relay-assets.tar.gz"
cmp "$REBUILD_ROOT/run-a/.build/relay/portable-relay-assets.tar.gz" \
    "$REPO/.temp/relay-known-good/portable-relay-assets.tar.gz"
shasum -a 256 "$REBUILD_ROOT/run-a/.build/relay/portable-relay-assets.tar.gz"
```

Expected result: both `cmp` commands are silent and exit `0`; the archive hash
is exactly `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`.
The four executable hashes must be:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `relux-relay-darwin-amd64` | 2,623,664 | `783b94982e90f0ceed0af0fa11662d11a333e244b87256cbfa0f7d21695f3290` |
| `relux-relay-darwin-arm64` | 2,487,362 | `8ac45b257099c9d2079b0bd2cb9ae489acfb86e443ba7ca7e4b4b2a56380d64c` |
| `relux-relay-linux-amd64` | 2,592,894 | `ddcb22ed4d4a978992a04096abae8adc58d0b8bf3bcdc0c0a006775797e2941f` |
| `relux-relay-linux-arm64` | 2,556,030 | `908b3d9ea3543b6144e2c99407c9aa02cc69e86c1cce80364d32dbdc3de8e0dc` |

### 5. Regenerate and check the trusted bundle manifest

```bash
REBUILT_ARCHIVE="$REBUILD_ROOT/run-a/.build/relay/portable-relay-assets.tar.gz"
REBUILT_BUNDLE_PARENT="$REPO/.build/relay/TASK-260715-u8tkx0"
mkdir -p "$REBUILT_BUNDLE_PARENT"
REBUILT_BUNDLE_ROOT="$(mktemp -d "$REBUILT_BUNDLE_PARENT/historical.XXXXXX")"
REBUILT_BUNDLE_A="$REBUILT_BUNDLE_ROOT/a"
REBUILT_BUNDLE_B="$REBUILT_BUNDLE_ROOT/b"
make relay-asset-bundle-generate \
  RELAY_ASSET_ARCHIVE="$REBUILT_ARCHIVE" \
  RELAY_ASSET_BUNDLE="$REBUILT_BUNDLE_A"
make relay-asset-bundle-check \
  RELAY_ASSET_ARCHIVE="$REBUILT_ARCHIVE" \
  RELAY_ASSET_BUNDLE="$REBUILT_BUNDLE_A"
make relay-asset-bundle-generate \
  RELAY_ASSET_ARCHIVE="$REBUILT_ARCHIVE" \
  RELAY_ASSET_BUNDLE="$REBUILT_BUNDLE_B"
make relay-asset-bundle-check \
  RELAY_ASSET_ARCHIVE="$REBUILT_ARCHIVE" \
  RELAY_ASSET_BUNDLE="$REBUILT_BUNDLE_B"
diff -qr "$REBUILT_BUNDLE_A" "$REBUILT_BUNDLE_B"
DEFAULT_TRUSTED_BUNDLE="$REPO/.build/relay/relay-assets-v1"
make relay-asset-bundle-generate \
  RELAY_ASSET_BUNDLE="$DEFAULT_TRUSTED_BUNDLE"
make relay-asset-bundle-check \
  RELAY_ASSET_BUNDLE="$DEFAULT_TRUSTED_BUNDLE"
cmp "$REBUILT_BUNDLE_A/relux-relay-assets-v1.json" \
    "$DEFAULT_TRUSTED_BUNDLE/relux-relay-assets-v1.json"
```

Expected tokens are `relay asset manifest generate passed` and `relay asset
manifest check passed`; `diff` and `cmp` are silent and exit `0`. Each bundle
must contain only the four canonical executables and
`relux-relay-assets-v1.json`. This step verifies the archive, schema, ordered
target set, exact bytes, embedded identity, provenance references, generated
Swift lookup, and atomic publication boundary.

### Historical metadata boundary

The accepted executable/archive recipe above predates deterministic SPDX
normalization. Raw Syft 1.48.0 output from that historical script contains a
random `documentNamespace` UUID and wall-clock `creationInfo.created`; rebuilding
it changes all four SPDX files and therefore the release-builder manifest and
checksum file. The accepted four executables, normalized archive, and trusted
application manifest are reproducible, but a newly generated historical
11-file release-builder tree is **not** claimed to equal retained historical
metadata. If that old release-builder tree is needed for an audit or rollback,
retrieve and hash its immutable retained bytes. Do not regenerate, normalize
after the fact, or relabel new Syft output as the historical evidence.

All new candidates must use the deterministic metadata path introduced by
`TASK-260715-1q03sa`: `SOURCE_DATE_EPOCH` fixes
`creationInfo.created`, the executable name and SHA-256 fix
`documentNamespace`, recursively sorted JSON fixes serialization, and the
comparator checks the exact 11-file release tree plus four protocol-test
executables. The executable audit below proves that supported current path.

## Strict update procedure

An update is a new reviewed candidate, not an in-place edit of the accepted
bundle. Execute the following order without bypass. Preserve commands, exit
codes, candidate hashes, and path-free reports in the candidate's task outcome.

1. **Freeze inputs.** Record candidate `SOURCE_COMMIT`, byte-affecting
   `RECIPE_COMMIT`, `SOURCE_DATE_EPOCH`, semantic `RELAY_VERSION`, Go/Syft
   identities, target matrix, and approved bundle budget. Keep source and
   recipe commits distinct when they are distinct.
2. **Review source, dependencies, and security.** Review the exact Git diff of
   `relay/cmd`, `relay/internal`, and `relay/go.mod`; confirm `go.sum` remains
   absent and the standard-library-only policy still holds; review Go and Syft
   security advisories and every component/license/source URL change. Update
   authoritative pins, not generated output. A dependency or toolchain change
   is never “checksum only.”
3. **Gate protocol compatibility.** Follow
   `TASK-260715-2z9b4a`, run `make relay-protocol-check`,
   `make relay-protocol-conformance-check`, and
   `make relay-protocol-hostile-diagnostics`. A relay version change does not
   by itself change protocol `1`. A schema, wire value, feature, limit, hello,
   or identity change requires compatible Swift and Go generation plus every
   consumer test; an unsupported protocol bump stops the update.
4. **Review toolchain pins.** Update `relay/toolchain-manifest-v1.json` only
   from immutable official archives and reviewed hashes. Run
   `make relay-toolchain-check relay-toolchain-negative-test` and reprovision
   from retained exact archives. Do not reuse an installed tree after its pin
   changes.
5. **Build in two independent clones.** Use the fresh-clone block below with
   reviewed candidate pins. For a single-commit source/recipe build with no
   overlay, use `--require-clean`. For a split-pin overlay, prove clean source
   first, overlay only the reviewed recipe files, prove the compiled-source
   diff, and use `--require-provenance`; do not falsely add `--require-clean` to
   a deliberately overlaid tree. Do not edit the accepted repository metadata
   or generated catalog during this candidate phase.
6. **Generate notices, deterministic SPDX, and provenance.** In each clone run
   the current `build` action. This is the candidate release-builder metadata
   boundary, not the repository supply-chain generator. It must normalize Syft
   metadata during generation and produce exactly four executables, four SPDX documents,
   `relux-relay-manifest-v1.json`, `relux-relay-SHA256SUMS`, the Go notice, and
   four protocol-test executables. Review the proposed source/build provenance,
   dependency inventory, license mappings, and notice content against those
   outputs, but do **not** run `make relay-supply-chain-generate` yet: that
   command validates the still-accepted asset contract and cannot accept a
   half-rotated source, version, or archive. Notice, inventory, provenance, or
   deterministic-metadata failure is red. Raw historical Syft output is
   retained evidence, not a reproducibility input.
7. **Prove full reproducibility.** Stage both outputs below one clone's
   `.build/relay/` containment root and run the exact comparator block below.
   Expected output is `relay reproducibility: identical=15/15`; it means 11
   release-builder files plus four protocol-test files matched in mode and
   SHA-256. No semantic exception or unexplained metadata variance is allowed.
   Normalize two four-member archives and require byte-identical archives.
8. **Run native smoke on all four targets.** Execute the native block below on
   an unprivileged matching `darwin/amd64`, `darwin/arm64`, `linux/amd64`, and
   `linux/arm64` host. Pass the release-builder
   `relux-relay-manifest-v1.json`, not the trusted-application
   `relux-relay-assets-v1.json`. Each bounded report must have
   `status: "pass"`, matching `target` and `runner.hostTarget`,
   `nativeEvidence.satisfied: true`, and exactly 17 passing checks. Emulation
   and Rosetta are additional evidence only. The four-row workflow is owned by
   `TASK-260715-36gq4m`; do not claim a remote CI row ran locally.
9. **Cross the coordinated metadata rotation boundary.** Only after all four
   native rows pass, retain the reviewed candidate archive as a task-scoped
   board outcome and execute the isolated rotation block below. One reviewed
   patch rotates the two source contracts, the supply-chain validator's relay
   version and accepted archive task/resource/SHA policy, both default archive
   paths, and the Swift acceptance assertions. Only then does
   `make relay-supply-chain-generate` rewrite the inventory, provenance,
   notices, asset-contract supply-chain reference, and generated Swift catalog.
   The block proves the ten-file patch and all generated outputs in an isolated
   clone before applying that patch to the accepted tree. Never invoke the
   generator against mutually inconsistent old/new contracts, and never
   hand-edit generated output.
10. **Validate the trusted bundle.** After the reviewed candidate archive and
    all ten coordinated files have been rotated together, execute the two
    independent generation/check block below and `make relay-asset-manifest-test`.
    Compare both complete five-file bundles. Missing, extra, renamed, symlinked,
    stale, or mismatched content is red.
11. **Validate Apple bundle integration without credentials.** Run
    `make workspace-generate workspace-validate` and
    `make macos-targets-validate`. Confirm the provider contains exactly the
    verified `relay-assets-v1` folder reference. This proves unsigned bundle
    input integration only; it does not prove application signing or
    notarization.
12. **Run downstream bootstrap consumers.** All ten concrete bootstrap tasks
    listed below must pass their selection, upload, remote verification,
    atomic install/reuse, stdio, lifecycle, hostile-output, upgrade, and
    operations tests against the new manifest. They are currently backlog, so
    an update cannot yet claim downstream bootstrap acceptance.
13. **Run M5 release gates.** Execute the M5 validation matrix, product notice
    and SBOM assembly, release provenance, Apple bundle enforcement, signing,
    notarization, attestation, and approval tasks listed below. Only the M5
    release approver can release the containing app.

### Executable deterministic full-release audit

Run this block from the repository root. The concrete pins reproduce the
accepted deterministic reference proof for the current metadata recipe; for an
actual update, replace them only with the pins frozen and reviewed in steps
1–4. The source commit and recipe commit remain separate evidence even when a
future candidate uses one commit for both.

```bash
set -eu
REPO="$(pwd -P)"
SOURCE_COMMIT=e8bd954a1985e0a3204504209f1b022f71e4d1f9
RECIPE_COMMIT=f21e24e25426bfafebb7f47b9f6d00f5c43d3e91
SOURCE_DATE_EPOCH=1787158980
RELAY_VERSION=0.0.0
mkdir -p "$REPO/.temp"
AUDIT_ROOT="$(mktemp -d "$REPO/.temp/TASK-260715-u8tkx0.full-release.XXXXXX")"

for RUN_NAME in run-a run-b; do
  RUN="$AUDIT_ROOT/$RUN_NAME"
  git clone --quiet --no-local --no-hardlinks --no-checkout "$REPO" "$RUN"
  git -C "$RUN" checkout --quiet --detach "$SOURCE_COMMIT"
  test -z "$(git -C "$RUN" status --porcelain=v1 --untracked-files=all)"
  git archive "$RECIPE_COMMIT" \
    Makefile scripts/relay_release.py relay/toolchain-manifest-v1.json \
    | tar -x -C "$RUN"
  git -C "$RUN" diff --exit-code "$SOURCE_COMMIT" -- \
    relay/cmd relay/internal relay/go.mod
  python3 "$RUN/scripts/relay_release.py" toolchain-check
  (
    cd "$RUN"
    python3 scripts/relay_release.py build \
      --go "$PINNED_GO" \
      --go-toolchain local \
      --syft "$PINNED_SYFT" \
      --relay-version "$RELAY_VERSION" \
      --source-commit "$SOURCE_COMMIT" \
      --source-date-epoch "$SOURCE_DATE_EPOCH" \
      --require-provenance \
      --output .build/relay/release \
      --test-output .build/relay/protocol-tests
  )
done

COMPARE_ROOT="$AUDIT_ROOT/run-a/.build/relay/cross-clone"
mkdir -p "$COMPARE_ROOT"
cp -R "$AUDIT_ROOT/run-a/.build/relay/release" \
  "$COMPARE_ROOT/run-a-release"
cp -R "$AUDIT_ROOT/run-a/.build/relay/protocol-tests" \
  "$COMPARE_ROOT/run-a-tests"
cp -R "$AUDIT_ROOT/run-b/.build/relay/release" \
  "$COMPARE_ROOT/run-b-release"
cp -R "$AUDIT_ROOT/run-b/.build/relay/protocol-tests" \
  "$COMPARE_ROOT/run-b-tests"
(
  cd "$AUDIT_ROOT/run-a"
  python3 scripts/relay_release.py compare \
    --first .build/relay/cross-clone/run-a-release \
    --second .build/relay/cross-clone/run-b-release \
    --first-tests .build/relay/cross-clone/run-a-tests \
    --second-tests .build/relay/cross-clone/run-b-tests
)

for RUN_NAME in run-a run-b; do
  RUN="$AUDIT_ROOT/$RUN_NAME"
  for TARGET_SLUG in darwin-amd64 darwin-arm64 linux-amd64 linux-arm64; do
    mkdir -p "$RUN/.build/relay/archive-input/$TARGET_SLUG"
    cp "$RUN/.build/relay/release/relux-relay-$TARGET_SLUG" \
      "$RUN/.build/relay/archive-input/$TARGET_SLUG/relux-relay-$TARGET_SLUG"
  done
  (
    cd "$RUN"
    python3 scripts/relay_release.py archive-assets \
      --portable-root .build/relay/archive-input \
      --archive .build/relay/portable-relay-assets.tar.gz \
      --source-date-epoch "$SOURCE_DATE_EPOCH"
  )
done
cmp "$AUDIT_ROOT/run-a/.build/relay/portable-relay-assets.tar.gz" \
    "$AUDIT_ROOT/run-b/.build/relay/portable-relay-assets.tar.gz"
shasum -a 256 \
  "$AUDIT_ROOT/run-a/.build/relay/portable-relay-assets.tar.gz" \
  "$AUDIT_ROOT/run-a/.build/relay/release/relux-relay-manifest-v1.json"
```

Every command must exit `0`. The comparator prints exactly
`relay reproducibility: identical=15/15`; the `cmp` invocation is silent.
For the concrete reference pins, the archive SHA-256 is
`09014b22e694b1ff4ab664c81d46b3afccd5a973f701cbd4625bfd88c093ab40`
and the release-builder manifest SHA-256 is
`ef5bd8b3cc41ce0e30c026bd088b370faeea30d789a7c6708631330afe8b049d`.
The build action performs exact-tree, manifest, checksum, notice, normalized
SPDX, protocol-test, and identity verification before returning.

The cross-clone copies are necessary: `compare` deliberately accepts output
paths only below the invoked checkout's `.build/relay/` root. Passing the two
clone paths directly is an expected containment failure, not a reproducibility
result.

### Native 17-check gate and unsupported-runtime red path

Run this block on the matching unprivileged host after setting `NATIVE_TARGET`
and `NATIVE_SLUG`. This example is the supported Apple-silicon row:

```bash
set -eu
NATIVE_TARGET=darwin/arm64
NATIVE_SLUG=darwin-arm64
RELEASE_ROOT="$AUDIT_ROOT/run-a/.build/relay/release"
SMOKE_ROOT="$REPO/.temp/TASK-260715-u8tkx0/runtime-evidence"
mkdir -p "$SMOKE_ROOT"
python3 scripts/relay_asset_smoke.py \
  --target "$NATIVE_TARGET" \
  --runner-kind native \
  --runner-name task-u8tkx0-darwin-arm64 \
  --runner-owner task-u8tkx0 \
  --require-native \
  --manifest "$RELEASE_ROOT/relux-relay-manifest-v1.json" \
  --executable "$RELEASE_ROOT/relux-relay-$NATIVE_SLUG" \
  --evidence "$SMOKE_ROOT/$NATIVE_SLUG.json"
python3 - "$SMOKE_ROOT/$NATIVE_SLUG.json" "$NATIVE_TARGET" <<'PY'
import json, sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["status"] == "pass"
assert report["target"] == sys.argv[2]
assert report["runner"]["kind"] == "native"
assert report["runner"]["hostTarget"] == sys.argv[2]
assert report["nativeEvidence"]["satisfied"] is True
assert len(report["checks"]) == 17
assert all(check["status"] == "pass" for check in report["checks"])
print("relay native smoke: pass=17/17")
PY
```

Expected result: the gate and assertion exit `0` and print `relay native
smoke: pass=17/17`. Repeat with the matching target/slug on the other three
native hosts. Never change `runner-kind` or omit `--require-native` to make a
required row green.

On a Darwin/arm64 host, exercise the unsupported-runtime path without starting
the mismatched Linux executable:

```bash
set -eu
UNSUPPORTED_REPORT="$SMOKE_ROOT/unsupported-linux-amd64.json"
set +e
python3 scripts/relay_asset_smoke.py \
  --target linux/amd64 \
  --runner-kind native \
  --runner-name task-u8tkx0-darwin-arm64 \
  --runner-owner task-u8tkx0 \
  --require-native \
  --manifest "$RELEASE_ROOT/relux-relay-manifest-v1.json" \
  --executable "$RELEASE_ROOT/relux-relay-linux-amd64" \
  --evidence "$UNSUPPORTED_REPORT"
UNSUPPORTED_EXIT=$?
set -e
test "$UNSUPPORTED_EXIT" -eq 1
python3 - "$UNSUPPORTED_REPORT" <<'PY'
import json, sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["status"] == "fail"
assert report["errorCode"] == "native_runner_identity_mismatch"
assert report["target"] == "linux/amd64"
assert report["runner"]["hostTarget"] == "darwin/arm64"
assert report["nativeEvidence"]["satisfied"] is False
assert "artifact" not in report
assert not any(check["processStarted"] for check in report["checks"])
print("relay unsupported runtime: rejected-before-start")
PY
```

Expected stderr is `relay-asset-smoke: native_runner_identity_mismatch`; the
gate exits `1`, the assertions exit `0`, and no relay process starts.

### Coordinated repository metadata rotation

This is the only supported boundary for changing an accepted relay source,
version, archive, or four-asset hash set. Candidate build steps 5–8 leave the
accepted repository metadata untouched. The generator is first invoked in an
isolated clone only after reproducibility and all four native rows are green;
the resulting reviewed patch is then applied as one unit.

The ordinary source/version/archive rotation has exactly these surfaces:

| Kind | Exact surface |
| --- | --- |
| Authoritative inputs | `relay/asset-bundle-source-v1.json`; `relay/supply-chain-source-v1.json` |
| Generator acceptance policy | `scripts/relay_supply_chain.py` — `APPROVED_RELAY_VERSION` and the exact `artifactManifest` archive task ID, resource name, and SHA-256 literal |
| Archive defaults | `scripts/relay_asset_manifest.py` — `DEFAULT_ARCHIVE`; `Makefile` — `RELAY_ASSET_ARCHIVE` |
| Acceptance assertion | `Tests/ReluxTunnelCoreTests/RelayAssetManifestTests.swift` — accepted task, archive SHA-256, relay version, and source commit |
| Generated by `make relay-supply-chain-generate` | `relay/dependency-inventory-v1.json`; `relay/source-build-provenance-v1.json`; `relay/PRODUCT_NOTICES.txt`; the `supplyChain` member of `relay/asset-bundle-source-v1.json`; `Sources/ReluxTunnelCore/RelayAssets/Generated/RelayAssetManifest+Generated.swift`; the five-file `.build/relay/relay-assets-v1/` bundle |

The resulting tracked patch contains ten files because the two source
contracts are counted once even though generation rewrites one of them. A Go,
Syft, license, protocol/schema, runtime-policy, ownership-boundary, or generator
change may add reviewed surfaces: update its exact allowlist and negative tests
in the same isolated patch and expand the asserted file set. Never weaken or
delete an exact validator to make a candidate pass.

Before running the block, export `ARCHIVE_TASK` as the concrete build task that
will own the retained archive and `ARCHIVE_RESOURCE` as its new task-scoped
resource name. Keep the variables from the deterministic build and native-smoke
blocks. The resource add intentionally fails if the name already exists; use a
new resource rather than overwriting known-good bytes.

```bash
set -eu
: "${REPO:?run the prerequisite block first}"
: "${AUDIT_ROOT:?run the deterministic build block first}"
: "${SOURCE_COMMIT:?set the reviewed source commit}"
: "${RECIPE_COMMIT:?set the reviewed recipe commit}"
: "${RELAY_VERSION:?set the reviewed relay version}"
: "${ARCHIVE_TASK:?export the concrete archive-owner task ID}"
: "${ARCHIVE_RESOURCE:?export the new archive resource name}"

CANDIDATE_RELEASE_ROOT="$AUDIT_ROOT/run-a/.build/relay/release"
CANDIDATE_RELEASE_MANIFEST="$CANDIDATE_RELEASE_ROOT/relux-relay-manifest-v1.json"
CANDIDATE_ARCHIVE="$AUDIT_ROOT/run-a/.build/relay/portable-relay-assets.tar.gz"
mkdir -p "$REPO/.temp"
ROTATION_ROOT="$(mktemp -d "$REPO/.temp/relay-metadata-rotation.XXXXXX")"
ROTATION_STAGE="$ROTATION_ROOT/repository"
VERIFIED_ARCHIVE="$ROTATION_ROOT/$ARCHIVE_RESOURCE"
ROTATION_PATCH="$ROTATION_ROOT/relay-metadata-rotation.patch"
ROTATION_BASE_COMMIT="$(git rev-parse HEAD)"
ROTATION_PATHS=(
  Makefile
  Sources/ReluxTunnelCore/RelayAssets/Generated/RelayAssetManifest+Generated.swift
  Tests/ReluxTunnelCoreTests/RelayAssetManifestTests.swift
  relay/PRODUCT_NOTICES.txt
  relay/asset-bundle-source-v1.json
  relay/dependency-inventory-v1.json
  relay/source-build-provenance-v1.json
  relay/supply-chain-source-v1.json
  scripts/relay_asset_manifest.py
  scripts/relay_supply_chain.py
)

test -f "$CANDIDATE_RELEASE_MANIFEST"
test -f "$CANDIDATE_ARCHIVE"
git diff --exit-code -- "${ROTATION_PATHS[@]}"
task-board resource add "$ARCHIVE_TASK" "$CANDIDATE_ARCHIVE" \
  --name "$ARCHIVE_RESOURCE" \
  --type outcome \
  --description "Reviewed four-target relay archive"
task-board resource get "$ARCHIVE_TASK" "$ARCHIVE_RESOURCE" \
  --output "$VERIFIED_ARCHIVE"
cmp "$CANDIDATE_ARCHIVE" "$VERIFIED_ARCHIVE"
ARCHIVE_SHA256="$(shasum -a 256 "$VERIFIED_ARCHIVE" | awk '{print $1}')"

git clone --quiet --no-local --no-hardlinks "$REPO" "$ROTATION_STAGE"
git -C "$ROTATION_STAGE" checkout --quiet --detach "$ROTATION_BASE_COMMIT"
mkdir -p "$ROTATION_STAGE/.task-board/.resources/$ARCHIVE_TASK"
cp "$VERIFIED_ARCHIVE" \
  "$ROTATION_STAGE/.task-board/.resources/$ARCHIVE_TASK/$ARCHIVE_RESOURCE"
```

The copy under the isolated clone is a generator fixture; the authoritative
resource was created through `task-board resource add`. Continue from the same
shell. This mechanical block derives Git hashes and asset tuples, but it does
not approve them; source, dependency, license, and protocol review happened in
steps 1–4.

```bash
(
  cd "$ROTATION_STAGE"
  python3 - \
    "$SOURCE_COMMIT" "$RECIPE_COMMIT" "$RELAY_VERSION" \
    "$ARCHIVE_TASK" "$ARCHIVE_RESOURCE" "$ARCHIVE_SHA256" \
    "$CANDIDATE_RELEASE_MANIFEST" <<'PY'
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

(
    source_commit,
    recipe_commit,
    relay_version,
    archive_task,
    archive_resource,
    archive_sha256,
    release_manifest_path,
) = sys.argv[1:]
root = Path.cwd()

def git_bytes(revision, path):
    return subprocess.run(
        ["git", "show", f"{revision}:{path}"],
        check=True,
        capture_output=True,
    ).stdout

def git_text(*arguments):
    return subprocess.run(
        ["git", *arguments],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.rstrip("\n")

def records(paths, revision):
    return [
        {"path": path, "sha256": hashlib.sha256(git_bytes(revision, path)).hexdigest()}
        for path in paths
    ]

def aggregate(items):
    payload = "".join(
        f'{item["sha256"]}  {item["path"]}\n' for item in items
    ).encode()
    return hashlib.sha256(payload).hexdigest()

def write_json(path, value):
    path.write_text(
        json.dumps(value, ensure_ascii=True, indent=2) + "\n",
        encoding="ascii",
    )

supply_path = root / "relay/supply-chain-source-v1.json"
asset_path = root / "relay/asset-bundle-source-v1.json"
supply = json.loads(supply_path.read_text(encoding="utf-8"))
asset = json.loads(asset_path.read_text(encoding="utf-8"))
release = json.loads(Path(release_manifest_path).read_text(encoding="utf-8"))
assert release["sourceCommit"] == source_commit
assert release["relayVersion"] == relay_version
assert [(item["os"], item["arch"]) for item in release["artifacts"]] == [
    ("darwin", "amd64"),
    ("darwin", "arm64"),
    ("linux", "amd64"),
    ("linux", "arm64"),
]

old_task = asset["buildProvenance"]["taskID"]
old_resource = asset["buildProvenance"]["resourceName"]
old_archive_sha256 = asset["buildProvenance"]["archiveSHA256"]
old_relay_version = asset["relayVersion"]
old_source_commit = asset["sourceCommit"]

source_records = records(
    [item["path"] for item in supply["source"]["byteAffectingFiles"]],
    source_commit,
)
source_url = (
    "https://github.com/relux-works/relux-tunnel/tree/"
    f"{source_commit}/relay"
)
supply["source"].update({
    "repository": source_url,
    "revision": source_commit,
    "repositoryTree": git_text("rev-parse", f"{source_commit}^{{tree}}"),
    "relayTree": git_text("rev-parse", f"{source_commit}:relay"),
    "sourceDateEpoch": int(
        git_text("show", "-s", "--format=%ct", source_commit)
    ),
    "aggregateSHA256": aggregate(source_records),
    "byteAffectingFiles": source_records,
})
supply["source"]["license"]["sha256"] = hashlib.sha256(
    git_bytes(source_commit, "LICENSE")
).hexdigest()
supply["dependencyLock"]["sha256"] = next(
    item["sha256"] for item in source_records if item["path"] == "relay/go.mod"
)

recipe_records = records(
    [item["path"] for item in supply["build"]["recipeFiles"]],
    recipe_commit,
)
recipe_url = (
    "https://github.com/relux-works/relux-tunnel/tree/" f"{recipe_commit}"
)
supply["build"].update({
    "recipeRevision": recipe_commit,
    "recipeSource": recipe_url,
    "recipeAggregateSHA256": aggregate(recipe_records),
    "recipeFiles": recipe_records,
    "command": (
        "make -j4 relay-toolchain-build-all "
        f"RELAY_VERSION={relay_version} SOURCE_COMMIT={source_commit} "
        f'SOURCE_DATE_EPOCH={supply["source"]["sourceDateEpoch"]} '
        "RELAY_BUILD_CLEAN_FLAG=--require-clean"
    ),
})
for component in supply["components"]:
    if component["id"] == "relux-relay-source":
        component.update({
            "version": relay_version,
            "revision": source_commit,
            "contentSHA256": supply["source"]["aggregateSHA256"],
            "source": source_url,
            "licenseTextSHA256": supply["source"]["license"]["sha256"],
        })
    elif component["id"] == "relay-build-recipe":
        component.update({
            "version": recipe_commit,
            "revision": recipe_commit,
            "contentSHA256": supply["build"]["recipeAggregateSHA256"],
            "source": recipe_url,
            "licenseTextSHA256": hashlib.sha256(
                git_bytes(recipe_commit, "LICENSE")
            ).hexdigest(),
        })

supply["artifactManifest"].update({
    "archiveTaskID": archive_task,
    "archiveResourceName": archive_resource,
    "archiveSHA256": archive_sha256,
})
asset.update({
    "relayVersion": relay_version,
    "sourceCommit": source_commit,
    "buildProvenance": {
        "kind": "taskBoardResource",
        "taskID": archive_task,
        "resourceName": archive_resource,
        "archiveSHA256": archive_sha256,
    },
    "assets": [
        {
            "os": item["os"],
            "arch": item["arch"],
            "archivePath": f'{item["os"]}-{item["arch"]}/{item["filename"]}',
            "fileName": item["filename"],
            "byteSize": item["size"],
            "sha256": item["sha256"],
        }
        for item in release["artifacts"]
    ],
})
write_json(supply_path, supply)
write_json(asset_path, asset)

validator_path = root / "scripts/relay_supply_chain.py"
text = validator_path.read_text(encoding="utf-8")
text, count = re.subn(
    r'^APPROVED_RELAY_VERSION = "[^"]+"$',
    f'APPROVED_RELAY_VERSION = "{relay_version}"',
    text,
    count=1,
    flags=re.MULTILINE,
)
assert count == 1
for key, value in (
    ("archiveTaskID", archive_task),
    ("archiveResourceName", archive_resource),
    ("archiveSHA256", archive_sha256),
):
    text, count = re.subn(
        rf'^(        "{key}": ")[^"]+(",)$',
        rf'\g<1>{value}\g<2>',
        text,
        count=1,
        flags=re.MULTILINE,
    )
    assert count == 1, key
validator_path.write_text(text, encoding="utf-8")

asset_tool_path = root / "scripts/relay_asset_manifest.py"
text = asset_tool_path.read_text(encoding="utf-8")
old_default = f'    / "{old_task}"\n    / "{old_resource}"'
new_default = f'    / "{archive_task}"\n    / "{archive_resource}"'
assert text.count(old_default) == 1
asset_tool_path.write_text(text.replace(old_default, new_default), encoding="utf-8")

makefile_path = root / "Makefile"
text = makefile_path.read_text(encoding="utf-8")
old_default = f".task-board/.resources/{old_task}/{old_resource}"
new_default = f".task-board/.resources/{archive_task}/{archive_resource}"
assert text.count(old_default) == 1
makefile_path.write_text(text.replace(old_default, new_default), encoding="utf-8")

test_path = root / "Tests/ReluxTunnelCoreTests/RelayAssetManifestTests.swift"
text = test_path.read_text(encoding="utf-8")
for old, new in (
    (old_task, archive_task),
    (old_archive_sha256, archive_sha256),
    (old_relay_version, relay_version),
    (old_source_commit, source_commit),
):
    assert text.count(old) == 1, old
    text = text.replace(old, new)
test_path.write_text(text, encoding="utf-8")
print(f"relay metadata rotation inputs: archive={archive_sha256}")
PY

  make relay-supply-chain-generate
  make relay-supply-chain-audit relay-supply-chain-test relay-asset-manifest-test
  make relay-asset-bundle-check
  git diff --check
  python3 - <<'PY'
import subprocess
expected = {
    "Makefile",
    "Sources/ReluxTunnelCore/RelayAssets/Generated/RelayAssetManifest+Generated.swift",
    "Tests/ReluxTunnelCoreTests/RelayAssetManifestTests.swift",
    "relay/PRODUCT_NOTICES.txt",
    "relay/asset-bundle-source-v1.json",
    "relay/dependency-inventory-v1.json",
    "relay/source-build-provenance-v1.json",
    "relay/supply-chain-source-v1.json",
    "scripts/relay_asset_manifest.py",
    "scripts/relay_supply_chain.py",
}
actual = set(subprocess.run(
    ["git", "diff", "--name-only"],
    check=True,
    capture_output=True,
    text=True,
).stdout.splitlines())
assert actual == expected, sorted(actual ^ expected)
print("relay metadata rotation: changed-files=10/10")
PY
  test "$(find .build/relay/relay-assets-v1 -type f | wc -l | tr -d ' ')" -eq 5
  git diff --binary -- "${ROTATION_PATHS[@]}" > "$ROTATION_PATCH"
)

git diff --exit-code -- "${ROTATION_PATHS[@]}"
git apply --check "$ROTATION_PATCH"
git apply "$ROTATION_PATCH"
make relay-supply-chain-generate
make relay-supply-chain-audit relay-supply-chain-test relay-asset-manifest-test
make relay-asset-bundle-check
for PATH_TO_COMPARE in "${ROTATION_PATHS[@]}"; do
  cmp "$PATH_TO_COMPARE" "$ROTATION_STAGE/$PATH_TO_COMPARE"
done
git diff --check
```

Every command must exit `0`. The generation/audit success tokens are `relay
supply-chain generate: pass`, `relay asset manifest generate passed`, `relay
supply-chain audit: pass`, and `relay asset manifest check passed`; the Python
assertion prints `relay metadata rotation: changed-files=10/10`. Both patch
guards and every final `cmp` are silent. A failure before `git apply` leaves the
accepted tree unchanged. A failure after `git apply` is a stopped, unaccepted
working-tree patch: do not partially copy outputs, change hashes to fit bytes,
or continue to bundle/bootstrap gates.

### Two trusted-application manifest generations and mismatch red path

After step 9 has rotated the candidate archive and checked-in source contract,
run from the repository root:

```bash
set -eu
CANDIDATE_ARCHIVE="$AUDIT_ROOT/run-a/.build/relay/portable-relay-assets.tar.gz"
TRUSTED_PARENT="$REPO/.build/relay/TASK-260715-u8tkx0"
mkdir -p "$TRUSTED_PARENT"
TRUSTED_ROOT="$(mktemp -d "$TRUSTED_PARENT/trusted.XXXXXX")"
TRUSTED_A="$TRUSTED_ROOT/a"
TRUSTED_B="$TRUSTED_ROOT/b"
python3 scripts/relay_asset_manifest.py generate \
  --archive "$CANDIDATE_ARCHIVE" --bundle "$TRUSTED_A"
python3 scripts/relay_asset_manifest.py check \
  --archive "$CANDIDATE_ARCHIVE" --bundle "$TRUSTED_A"
python3 scripts/relay_asset_manifest.py generate \
  --archive "$CANDIDATE_ARCHIVE" --bundle "$TRUSTED_B"
python3 scripts/relay_asset_manifest.py check \
  --archive "$CANDIDATE_ARCHIVE" --bundle "$TRUSTED_B"
diff -qr "$TRUSTED_A" "$TRUSTED_B"
test "$(find "$TRUSTED_A" -type f | wc -l | tr -d ' ')" -eq 5
cmp "$TRUSTED_A/relux-relay-assets-v1.json" \
    "$TRUSTED_B/relux-relay-assets-v1.json"
make relay-asset-manifest-test
```

Both generators print `relay asset manifest generate passed`, both checks print
`relay asset manifest check passed`, `diff` and `cmp` are silent, and each
bundle contains exactly four executables plus
`relux-relay-assets-v1.json`. For the currently accepted historical archive,
use `REBUILT_ARCHIVE` from the earlier rebuild instead of `CANDIDATE_ARCHIVE`;
both manifests must also compare byte-for-byte with
`.build/relay/relay-assets-v1/relux-relay-assets-v1.json` after generating that
default trusted bundle.

Exercise hash/size drift only on a copied bundle:

```bash
set -eu
MISMATCH_BUNDLE="$TRUSTED_ROOT/mismatch-copy"
MISMATCH_LOG="$REPO/.temp/TASK-260715-u8tkx0/mismatch.log"
mkdir -p "$(dirname "$MISMATCH_LOG")"
test ! -e "$MISMATCH_BUNDLE"
cp -R "$TRUSTED_A" "$MISMATCH_BUNDLE"
printf x >> "$MISMATCH_BUNDLE/relux-relay-linux-amd64"
set +e
make relay-asset-bundle-check \
  RELAY_ASSET_ARCHIVE="$CANDIDATE_ARCHIVE" \
  RELAY_ASSET_BUNDLE="$MISMATCH_BUNDLE" \
  >"$MISMATCH_LOG" 2>&1
MISMATCH_EXIT=$?
set -e
test "$MISMATCH_EXIT" -eq 2
grep -F "relay asset size does not match the manifest" "$MISMATCH_LOG"
```

Expected result: `make` exits `2`, the diagnostic is present, and the copied
asset is never executed. Delete or quarantine only the copied test fixture;
never repair it by rotating the trusted manifest to its hash.

## Rollback procedure

Rollback selects a retained known-good manifest and its exact bytes. It does
not rebuild “equivalent” files, decrement a version in place, or trust a remote
copy because its filename looks right.

1. Freeze the suspect candidate and stop promotion, upload, bootstrap, signing,
   and publication. Record its non-sensitive version, source/recipe/tool pins,
   manifest digest, four asset digests, failed gate, and exit code.
2. Select an already accepted known-good set containing the archive,
   `asset-bundle-source-v1.json`, manifest schema, generated Swift catalog,
   source/dependency provenance, inventory, notices, and toolchain pins. Verify
   the retained archive before extraction. The current known-good archive is
   the `TASK-260715-24icoz` resource and has SHA-256 `1f0ba226…eef4e`.
3. Regenerate into a new task-scoped bundle directory and run
   `relay-asset-bundle-check`, the full supply-chain audit, native rows, bundle
   integration, and downstream bootstrap tests. Compare the regenerated
   manifest and every file to the retained known-good set.
4. Restore the source contracts and generated catalog to the known-good
   manifest as one reviewed change. Preserve the failed candidate evidence;
   never overwrite or relabel it as known-good.
5. Let remote versions **coexist** when the bootstrap implementation uses a
   private version/hash-qualified path. New sessions select only the exact
   known-good manifest digest; old and new files are not interchangeable.
6. If coexistence is unavailable, stop affected relay sessions before
   **replacement**. Upload to a private temporary path, verify exact size and
   SHA-256 on the remote host using an approved verifier or the defined
   protocol fallback, then atomically rename. Retain or remove the old file
   only according to the bootstrap ownership contract. Never execute the
   temporary or final path before verification.
7. Re-run selection, upload interruption cleanup, remote hash fallback,
   install/reuse, identity, stdio, shutdown, and upgrade/rollback matrix tests.
   Release only the containing app through the separate M5 decision.

The remote coexistence/replacement implementation is future work owned by
`TASK-260715-19lr1c` and `TASK-260715-2lfgwo`; until those tasks are accepted,
the steps describe the required gate, not a currently runnable remote command.

## Incident and mismatch response

| Symptom | Contain and diagnose | Recovery and owner |
| --- | --- | --- |
| Hash drift or size drift | Stop promotion and execution; preserve the manifest, observed digest/size, command exit, and immutable input pins; compare both clean builds and the retained archive. Do not “rotate” the manifest to the unexplained bytes. | Rebuild from pinned source/recipe/tool inputs. If both builds agree but differ from the accepted set, treat it as an unapproved update. M2: `TASK-260715-1q03sa`, `TASK-260715-1ue4oy`; M5 traceability: `TASK-260715-3c06k7`. |
| Missing or extra target | Fail the exact-tree gate. Do not ship a three-target bundle or substitute another architecture. | Rebuild all four; rerun manifest and native rows. M2: `TASK-260715-24icoz`; M5 matrix: `TASK-260715-1c4l9v`. |
| Unsupported native runtime or containment | Record a red `required_native_runner_missing`, architecture mismatch, or containment failure. Cross-build/emulation is not a pass. | Route to the native owner/runner and rerun rootless. M2 smoke: `TASK-260715-mocqmr`; workflow: `TASK-260715-36gq4m`. |
| Notice, SPDX, inventory, or provenance failure | Quarantine the candidate; do not omit the file or copy a prior version. Compare component/license/source mappings and exact generated bytes. | Correct authoritative inputs, regenerate, and audit. M2: `TASK-260715-vtot05`; M5: `TASK-260715-151xf0`, `TASK-260715-37rtzn`, `TASK-260715-28y0uc`. |
| Bundle or generated Swift mismatch | Do not edit the bundle, compact manifest, or Swift file by hand. Preserve the stale/suspect directory and gate diagnostic. | Regenerate atomically from the verified archive, then run bundle and provider graph tests. M2: `TASK-260715-1ue4oy`; M5: `TASK-260715-1lmmri`. |
| Suspected compromised asset | Stop execution and distribution; quarantine hashes and immutable copies without opening/running them; identify every containing app/candidate and remote hash that consumed them. | Select a pre-compromise known-good set, rotate/revoke affected release/update credentials through `TASK-260715-1g658s` and their M5 owners, rebuild on a clean trusted host, rerun every consumer, and issue the release decision through `TASK-260715-312u2k`. |
| Suspected compromised source, tool archive, builder, or CI action | Stop all candidates derived from the affected input. Preserve Git object IDs, archive hashes, provenance receipts, runner identity, and CI run IDs. Do not reuse installed tool trees or caches. | Re-establish trust from independently verified immutable source/tool inputs, reprovision, double-build, compare, and re-attest. Escalate organization-wide response outside this runbook. |

Credential-safe evidence contains task ID, UTC time, target, runner class,
tool/version/commit, source and recipe commits, manifest/archive/file SHA-256,
byte sizes, stable check name, bounded error code, observed exit code, and CI run
ID. Do not attach environment dumps, absolute workstation paths, usernames,
hostnames or IPs, SSH command text, remote shell output, Keychain references,
tokens, cookies, private keys, signing material, or captured relay payloads.
The runtime smoke report is the preferred bounded format.

Compromise containment, credential revocation/rotation, external notification,
and organization-wide incident command require the security/release owners;
this runbook does not authorize those human decisions. It does require the
relay owner to keep the candidate stopped until those owners clear it.

## Responsibility boundary

| Control | Responsible | Accountable gate | Consulted / informed | Boundary |
| --- | --- | --- | --- | --- |
| Relay source and dependency integrity | M2 relay maintainer | `TASK-260715-27uz4n`, `TASK-260715-vtot05` | protocol owner | Exact source/recipe/tool/license inputs only |
| Reproducible four-target bytes | M2 relay build maintainer | `TASK-260715-24icoz`, `TASK-260715-1q03sa` | native runner owners | Unsigned executable bytes and normalized archive |
| Trusted manifest, checksums, generated Swift, and bundle hashes | M2 asset packaging owner | `TASK-260715-1ue4oy` | Apple bundle owner | Hash/identity verification; no Apple identity claim |
| Relay notices and relay-scoped inventory/provenance | M2 supply-chain owner | `TASK-260715-vtot05` | M5 compliance | Relay input only; product-wide assembly stays M5 |
| Product notices and release SBOM | M5 compliance | `TASK-260715-151xf0`, `TASK-260715-37rtzn` | relay owner | Final containing-product evidence |
| Remote selection, upload, verification, install, and execution | bootstrap/session owner | ten bootstrap tasks below | relay and security owners | No remote file executes before exact verification |
| Apple bundle enforcement | M5 release engineering | `TASK-260715-1lmmri` | M2 asset owner | Consumes exact verified M2 bundle |
| Application/system-extension signing | M5 Apple release owner | `TASK-260715-3sk5cd` | security/release approver | Does not make the relay a standalone signed download |
| Notarization and Gatekeeper | M5 Apple release owner | `TASK-260715-387eof` | release approver | Containing Apple deliverable only |
| Release provenance/attestation | M5 release engineering | `TASK-260715-1gzhnk`, `TASK-260715-28y0uc` | M2 owners | Binds signed release deliverables and exact M2 inputs |
| Release approval | authorized human approver | `TASK-260715-312u2k` | all owners | Only this boundary authorizes channel promotion |

## Concrete gate and consumer index

Statuses below were verified on 2026-08-19. Re-query before each update with
`task-board q --format compact 'get(TASK-ID) { id name status parent }'`.

### M2 build gates

- [`TASK-260715-27uz4n` — establish pinned portable relay build toolchain (done)](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-3pv7qc_relay-portable-build-assets/TASK-260715-27uz4n_establish-pinned-portable-relay-build-toolchain/README.md)
- [`TASK-260715-2ywde4` — implement relay entrypoint, build identity, and self-hash (done)](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-3pv7qc_relay-portable-build-assets/TASK-260715-2ywde4_implement-relay-entrypoint-build-identity-and-self-hash/README.md)
- [`TASK-260715-24icoz` — build the four declared portable relay assets (done)](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-3pv7qc_relay-portable-build-assets/TASK-260715-24icoz_build-four-platform-relay-assets/README.md)
- [`TASK-260715-1ue4oy` — generate and embed the relay asset manifest (done)](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-3pv7qc_relay-portable-build-assets/TASK-260715-1ue4oy_generate-and-embed-relay-asset-manifest/README.md)
- [`TASK-260715-vtot05` — add relay license, provenance, and supply-chain metadata (done)](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-3pv7qc_relay-portable-build-assets/TASK-260715-vtot05_add-relay-license-provenance-and-supply-chain-metadata/README.md)
- [`TASK-260715-mocqmr` — add portable-asset CI smoke and boundary tests (done)](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-3pv7qc_relay-portable-build-assets/TASK-260715-mocqmr_add-portable-asset-ci-smoke-and-boundary-tests/README.md)
- [`TASK-260715-1q03sa` — verify reproducible relay assets (done)](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-3pv7qc_relay-portable-build-assets/TASK-260715-1q03sa_verify-reproducible-relay-assets/README.md)

The protocol update gate is
[`TASK-260715-2z9b4a` — document protocol compatibility and change gates (done)](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-18ncz1_relay-protocol-conformance/TASK-260715-2z9b4a_document-protocol-compatibility-and-change-gates/README.md).

### Downstream bootstrap consumers

All are currently backlog and therefore future gates:

- [`TASK-260715-2uipar` — remote platform probe and asset selection](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2etfkl_relay-bootstrap-and-session/TASK-260715-2uipar_implement-remote-platform-probe-and-asset-selection/README.md)
- [`TASK-260715-1jga46` — shell-safe relay path and command builder](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2etfkl_relay-bootstrap-and-session/TASK-260715-1jga46_implement-shell-safe-relay-path-and-command-builder/README.md)
- [`TASK-260715-1bj8hu` — exec-stdin upload and interruption cleanup](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2etfkl_relay-bootstrap-and-session/TASK-260715-1bj8hu_implement-exec-stdin-upload-and-interruption-cleanup/README.md)
- [`TASK-260715-fve0hj` — remote checksum verification fallbacks](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2etfkl_relay-bootstrap-and-session/TASK-260715-fve0hj_implement-remote-checksum-verification-fallbacks/README.md)
- [`TASK-260715-19lr1c` — private atomic relay install and reuse](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2etfkl_relay-bootstrap-and-session/TASK-260715-19lr1c_implement-private-atomic-relay-install-and-reuse/README.md)
- [`TASK-260715-159pcp` — stdio relay launch and handshake](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2etfkl_relay-bootstrap-and-session/TASK-260715-159pcp_implement-stdio-relay-launch-and-handshake/README.md)
- [`TASK-260715-9h7pf8` — relay health, shutdown, and failure monitoring](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2etfkl_relay-bootstrap-and-session/TASK-260715-9h7pf8_implement-relay-health-shutdown-and-failure-monitoring/README.md)
- [`TASK-260715-1ge5hs` — bootstrap command and hostile-output tests](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2etfkl_relay-bootstrap-and-session/TASK-260715-1ge5hs_add-bootstrap-command-and-hostile-output-tests/README.md)
- [`TASK-260715-2lfgwo` — remote bootstrap failure and upgrade matrix](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2etfkl_relay-bootstrap-and-session/TASK-260715-2lfgwo_add-remote-bootstrap-failure-and-upgrade-matrix/README.md)
- [`TASK-260715-1iwpn0` — bootstrap capability reasons and operations](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2etfkl_relay-bootstrap-and-session/TASK-260715-1iwpn0_document-bootstrap-capability-reasons-and-operations/README.md)

### M5 bundle, compliance, and release gates

The M2 runbook produces unsigned hash-verifiable inputs. These tasks are all
currently backlog and own the later validation and release boundaries:

- [`TASK-260715-1c4l9v` — execute the relay release asset validation matrix](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-19mjyn_relay-supply-chain-and-compliance/TASK-260715-1c4l9v_execute-relay-release-asset-validation-matrix/README.md)
- [`TASK-260715-36gq4m` — add the relay release build and conformance workflow](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-anxje6_continuous-integration-quality-gates/TASK-260715-36gq4m_add-relay-release-build-and-conformance-workflow/README.md)
- [`TASK-260715-1lmmri` — enforce Apple bundle relay selection and integrity](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-19mjyn_relay-supply-chain-and-compliance/TASK-260715-1lmmri_enforce-apple-bundle-relay-selection-and-integrity/README.md)
- [`TASK-260715-151xf0` — assemble third-party notices and license evidence](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-19mjyn_relay-supply-chain-and-compliance/TASK-260715-151xf0_assemble-third-party-notices-and-license-evidence/README.md)
- [`TASK-260715-37rtzn` — generate the relay dependency SBOM](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-19mjyn_relay-supply-chain-and-compliance/TASK-260715-37rtzn_generate-relay-dependency-sbom/README.md)
- [`TASK-260715-nwcp1j` — enforce relay license, vulnerability, and secret policy](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-19mjyn_relay-supply-chain-and-compliance/TASK-260715-nwcp1j_enforce-relay-license-vulnerability-and-secret-policy/README.md)
- [`TASK-260715-28y0uc` — produce relay provenance and release staging bundle](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-19mjyn_relay-supply-chain-and-compliance/TASK-260715-28y0uc_produce-relay-provenance-and-release-staging-bundle/README.md)
- [`TASK-260715-3c06k7` — audit relay source-to-staging compliance traceability](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-19mjyn_relay-supply-chain-and-compliance/TASK-260715-3c06k7_audit-relay-source-to-staging-compliance-traceability/README.md)
- [`TASK-260715-3sk5cd` — implement inside-out hardened-runtime signing](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-c1qsc6_macos-signed-distribution/TASK-260715-3sk5cd_implement-inside-out-hardened-runtime-signing/README.md)
- [`TASK-260715-387eof` — notarize, staple, and Gatekeeper-validate the macOS candidate](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-c1qsc6_macos-signed-distribution/TASK-260715-387eof_notarize-staple-and-gatekeeper-validate-macos-candidate/README.md)
- [`TASK-260715-1gzhnk` — generate macOS provenance, checksums, and compliance bundle](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-c1qsc6_macos-signed-distribution/TASK-260715-1gzhnk_generate-macos-provenance-checksums-and-compliance-bundle/README.md)
- [`TASK-260715-312u2k` — record the release-readiness go/no-go decision](../.task-board/EPIC-260716-3fyjn0_manual-validation-and-approvals/STORY-260716-2byjks_m5-release-gates-and-ceremonies/TASK-260715-312u2k_record-release-readiness-go-no-go-decision/README.md)
- [`TASK-260715-1z8ac2` — document the broader M5 relay update, rollback, and incident runbook](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-19mjyn_relay-supply-chain-and-compliance/TASK-260715-1z8ac2_document-relay-update-rollback-and-incident-runbook/README.md)
- [`TASK-260715-1g658s` — write the cross-platform rollback, incident, and revocation runbook](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-2dtdql_release-operations-privacy-and-review/TASK-260715-1g658s_write-cross-platform-rollback-incident-and-revocation-runbook/README.md)

The future M5 runbook must consume rather than weaken this M2 byte boundary.

## Handoff checklist

- The four accepted historical executables/archive and trusted application
  manifest were rebuilt from recorded pins; any historical release-builder
  metadata was verified as retained exact bytes rather than regenerated.
- A new candidate's two deterministic 11-file release trees, four protocol-test
  executables, and normalized archives matched byte-for-byte.
- Supply-chain, notice, SPDX, provenance, checksum, manifest, native runtime,
  bundle, Apple integration, and bootstrap consumer results are attached with
  real exit codes.
- The known-good rollback archive and metadata remain immutable and retrievable.
- No standalone signing claim, remote pre-verification execution, credential
  evidence, local-only native claim, or future backlog gate is represented as a
  pass.
