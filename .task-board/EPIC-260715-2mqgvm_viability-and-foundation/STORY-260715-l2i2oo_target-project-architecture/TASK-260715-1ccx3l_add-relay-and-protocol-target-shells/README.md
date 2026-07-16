# Add relux-relay and protocol-test target shells

## Description
Create buildable target shells for the portable relux-relay executable and its protocol tests using the approved relay language and cross-build toolchain. Establish artifact naming, version reporting, manifest inputs, and test entry points without implementing UDP relay behavior.

## Scope
In scope: source and test target layout; toolchain pin; Linux and macOS x86_64 and arm64 build definitions; version and protocol constants; stdio no-op or health smoke behavior; checksum and manifest schema; license and SBOM hooks; Apple-bundle input path. Out of scope: UDP sockets, association tracking, framing implementation beyond a versioned empty smoke contract, remote deployment, SSH exec, and release publication.

## Acceptance Criteria
1. The pinned toolchain produces the named executable and test artifacts for all four required OS and architecture combinations or records an approved, reproducible native-build matrix where cross-compilation is unsafe. 2. Each binary reports source revision, build target, executable version, and protocol version through a deterministic smoke command. 3. Checksums and a manifest are generated with stable field names and no host-specific paths. 4. Protocol tests have a runnable entry point and one version-mismatch smoke case. 5. License and SBOM hooks execute even with the empty dependency set, and no relay feature behavior is implied.
