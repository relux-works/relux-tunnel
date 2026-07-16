# Pin relay release build environments and dependency inputs

## Description
Turn the approved relay contract into immutable build inputs for every target, including source revisions, dependency locks, compiler and linker toolchains, SDK or sysroot identity, and hermetic fetch behavior.

## Scope
In scope: relay source and generated protocol revision, HEV or other native dependency pins used by the relay, package locks, container image digests, macOS Xcode or SDK identity, cross toolchains and sysroots, checksum-verified downloads, offline or post-fetch builds, locale and timezone, path remapping, compiler flags, and input inventory. Out of scope: building final assets, changing dependency choices without a decision, Apple application dependencies not shipped with relay, and storing credentials in images or locks.

## Acceptance Criteria
1. Every source, dependency, generator, toolchain, image, SDK, sysroot, and downloaded archive is addressed by immutable revision and cryptographic digest where supported. 2. A clean bootstrap verifies all digests before use and the actual build can run without resolving mutable branches, tags, latest URLs, or undeclared network inputs. 3. Environment, locale, timezone, paths, compiler flags, linker flags, archive ordering, and build metadata are normalized per the reproducibility contract. 4. The input inventory records licenses and provenance and contains no access tokens, private registry credentials, developer home paths, or private key material. 5. Controlled pin, digest, lock, image, SDK, flag, and undeclared-fetch drift fails before compilation.
