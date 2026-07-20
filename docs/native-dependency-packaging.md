# Native dependency packaging seam

`TASK-260715-1g9cyt` establishes the extension-safe packaging boundary used by
HEV/lwIP and either SSH candidate. The checked-in harmless fixture exercises the
same path without selecting or integrating a production transport.

## Decision

ADR-019 selects a static XCFramework SwiftPM `binaryTarget` for custom-build C
graphs. HEV is not a practical SwiftPM C-source target: its pinned build merges
the tunnel, core, task-system, lwIP, and yaml archives, applies platform-specific
sources and flags, and is already verified upstream as an XCFramework. A local
source build retains those semantics and gives one inspectable static archive
per Apple slice. Dynamic libraries, runtime downloads, `dlopen`, private
frameworks, and unchecked vendor binaries are prohibited.

This is not permission for opaque binary updates. Every artifact update must
include the pinned revision and source hash, compiler flags, target triples,
license inputs, rebuild command, and per-file artifact hashes in
[`NativeDependencies/manifest.json`](../NativeDependencies/manifest.json).
The checked-in source or pinned upstream graph is the review authority. CI
rebuilds the artifact and requires byte-identical file hashes before accepting
the binary diff.

Swift dependencies whose upstream package graph is itself the reviewed source,
such as a possible `ReluxNIOSSH` fork, stay normal pinned SwiftPM source
dependencies. They do not need an XCFramework merely for uniformity.

## Target graph

```text
ReluxTunnelCore                       (no native or platform dependency)
        ^
        |
ReluxTunnelNativeAdapter ----------> CReluxNativeFixture binaryTarget
        |                         `-> HevSocks5Tunnel binaryTarget
        ^                                      |
        |                                      `-- static XCFrameworks only
        +-- ReluxTunnelIOSAdapter
        +-- ReluxTunnelMacOSAdapter
        `-- ReluxTunnelHarnessSupport --> ReluxTunnelHarness
```

The HEV integration now occupies `ReluxTunnelNativeAdapter` itself: the adapter
depends on Core contracts plus the pinned `HevSocks5Tunnel` binary target and
supplies the bridge's real scoped-borrow consumer. A possible
`ReluxTunnelLibSSH2Adapter` occupies the same layer. Provider and harness
composition roots retain the named adapter dependency; `ReluxTunnelCore` and
its public contracts do not change direction. A `ReluxNIOSSHAdapter` uses the
same layer but depends on the pinned Swift source package instead of a binary
target.

## Rebuild and verification

The harmless fixture is rebuilt from the manifest inputs with:

```sh
./scripts/native-dependency-tool.py build-fixture \
  --output NativeDependencies/Artifacts/ReluxNativeFixture.xcframework
make validate-native
```

The build creates iOS device arm64, iOS Simulator arm64/x86_64, and macOS
arm64/x86_64 static archives. All C compilations use `-fapplication-extension`.
The validator checks the plist slice declarations against the archives, rejects
missing architectures, non-static binaries, dynamic-loader symbols and load
commands, absolute build paths, missing module maps, source-hash drift, artifact
hash drift, and stale notices. Xcode builds run with
`APPLICATION_EXTENSION_API_ONLY=YES` for both provider destinations. Linked
release products are stripped of debug/source tables before signing and the
linked-binary audit; the audit rejects any remaining absolute checkout path or
non-system dynamic dependency. The generated Xcode package scheme proves the
universal macOS compile/link configuration; the linked-product audit uses the
non-instrumented SwiftPM release harness because Xcode's generated package
scheme injects test-coverage paths that are not part of production packaging.

The pinned HEV graph is rebuilt only from a disposable recursive checkout:

```sh
./scripts/native-dependency-tool.py build-hev \
  --source-dir /path/to/pinned/hev-socks5-tunnel \
  --output NativeDependencies/Artifacts/HevSocks5Tunnel.xcframework \
  --notices NativeDependencies/Generated/HEV_THIRD_PARTY_NOTICES.txt
```

Before invoking upstream `build-apple.sh`, the command verifies the root and all
four submodule revisions and deterministic git-archive SHA-256 values from the
manifest. A mismatch fails before compilation. After compilation it performs
the same static/slice/extension-safety inspection, verifies the per-file artifact
lock, and emits notices directly from the verified license files into both the
generated evidence location and a generated static Swift notice API (avoiding
SwiftPM's absolute build-path resource fallback). The Apple matrix
builds the native adapter and both provider configurations for iOS device, iOS
Simulator, and macOS, then proves that the stripped harness contains HEV's
`main_from_str`, `quit`, and `stats` symbols.

At runtime the adapter generates HEV configuration in memory, lends only the
bridge-owned endpoint B to one dedicated pthread, calls the public unmodified
quit API, joins that pthread, and leaves descriptor closure to bridge cleanup.
Its SOCKS side binds only IPv4 loopback and requires fresh per-run RFC 1929
credentials before an accepted channel can reach the injectable adapter seam.
The pending-authentication limit and timeout remain caller-owned inputs.

## Cache policy

The optional build cache root is named by `RELUX_NATIVE_CACHE_DIR`; when unset,
automation may use `relux-native-dependencies` below the process temporary
directory. Cache keys include dependency, revision, source hash, Xcode build,
and compiler flags. Cache contents are never authoritative: source verification
and artifact inspection always run on a hit. A mismatch deletes only that keyed
entry and then rebuilds. No dependency is downloaded or loaded at application
runtime.

## Candidate plug-in checklist

For a new custom native graph such as libssh2:

1. Add the exact upstream graph, source hashes, licenses, flags, and slices to
   the manifest.
2. Add a fail-closed verifier/build recipe and generated notice hook.
3. Inspect the static XCFramework and lock its per-file hashes.
4. Add a named adapter target depending on Core plus the binary target.
5. Run provider, harness, archive, architecture, and extension-safety gates.

For ReluxNIOSSH, pin the source revision and package checksum/identity, place its
concrete implementation in a named SSH adapter, and run the same provider and
harness matrix. ADR-014 still owns the SSH engine selection; this seam does not
pre-decide it.

The source fork now lives as the independent package
`Dependencies/ReluxNIOSSH`, pinned and diff-verified against SwiftNIO SSH
`0.14.1` / `31cdc3c3391a10460dedf1170530cf651d2ca496`. It deliberately keeps
the `NIOSSH` product/module name for source compatibility. The later
`ReluxNIOSSHAdapter` target may add it as a package dependency; no
`ReluxTunnelCore` target depends on it.

The libssh2 candidate uses the C side of the same seam. `ReluxLibSSH2` is a
static XCFramework binary target rebuilt from checksum-verified libssh2
`a34302491c164d53c900fec9b3cbb050ecebe719` plus OpenSSL `3.5.7`. The source
tool verifies both archives before extraction or patching, applies the single
six-file allowlisted observation patch in a disposable tree, and merges static
libssh2 and libcrypto archives per architecture. It then enforces the existing
architecture, minimum-OS, static-link, forbidden-symbol, extension-safety,
absolute-path, public-header, notice, and artifact-lock gates. Its stable
logical OpenSSL prefix prevents task-local build paths from entering runtime
metadata.

```sh
make build-libssh2 \
  LIBSSH2_SOURCE_ARCHIVE=/path/to/libssh2-a343024.tar.gz \
  OPENSSL_SOURCE_ARCHIVE=/path/to/openssl-3.5.7.tar.gz
make validate-libssh2
```

The target is intentionally not attached to `ReluxTunnelCore` or the existing
shared native adapter. `TASK-260715-1ozsb6` owns the future named libssh2
adapter dependency; that adapter may import only the XCFramework's public
module and headers. Fork provenance, exact delta, and rebase policy live under
[`Dependencies/ReluxLibSSH2`](../Dependencies/ReluxLibSSH2/README.md).
