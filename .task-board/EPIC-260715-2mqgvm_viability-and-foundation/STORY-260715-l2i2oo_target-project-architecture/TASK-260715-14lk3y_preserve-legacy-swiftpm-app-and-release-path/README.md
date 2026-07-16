# Preserve the legacy SwiftPM app and release path

## Description
Adapt repository build entry points only as needed so the generated workspace can coexist with the current ReluxProxy SwiftPM executable, tests, menu-bar app packaging, DMG creation, defaults, and release artifact contract.

## Scope
In scope: coexistence of Package.swift and generated workspace; existing swift build and swift test; Makefile commands; app and DMG scripts; universal build expectation; Info.plist and default values; stable ReluxProxy.dmg naming; explicit deprecation boundary; regression checks. Out of scope: refactoring legacy source, sandboxing system SSH, changing user-visible defaults, rewriting release signing, adding iOS release automation, or retiring the current product.

## Acceptance Criteria
1. Existing swift test, swift build, make app, and applicable credential-free packaging checks retain their documented behavior after project generation. 2. The current host, account, and SOCKS port defaults and system-SSH command construction tests remain unchanged unless a separately approved migration record says otherwise. 3. Generated targets do not overwrite legacy Info.plist, product name, bundle path, or release assets. 4. A regression script or CI job fails on accidental removal or silent identity migration. 5. Any unavoidable incompatibility is recorded as a stop-the-line decision with options before changing legacy behavior.
