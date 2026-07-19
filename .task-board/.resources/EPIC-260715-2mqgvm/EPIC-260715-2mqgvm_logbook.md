# EPIC-260715-2mqgvm planning logbook

## 2026-07-15 — Gate A0 is not implied by Gate P0

Successful entitlement provisioning and provider launch prove capability access,
not Apple acceptance of the intended local TCP termination plus SSH architecture.
Gate A0 therefore has its own primary-source, disclosure, authoritative evidence,
assessment, and disposition chain. The generated production foundation depends on
both Gate A0 and Gate P0.

## 2026-07-15 — Preserve the shipped SwiftPM product

The repository currently contains one macOS 14 SwiftPM menu-bar application that
launches system SSH, plus SwiftPM tests, app and DMG scripts, and a stable release
artifact contract. The generated Apple workspace must coexist with that product.
Silent source migration, default changes, identity replacement, or release-path
retirement is prohibited until a separate decision explicitly authorizes it.

## 2026-07-15 — Relay implementation stack was unspecified

The supplied platform plan requires a portable `relux-relay` and protocol-test
target for Linux and macOS on x86_64 and arm64, but does not choose a language or
toolchain. TASK-260715-3bdplx now blocks the target shell until that decision has
reproducible portability evidence.

## 2026-07-15 — SSH memory selection consumes the packet baseline

SSH functional candidate work can use the generated harness, but final comparative
scale and memory evidence must account for measured PacketFlowBridge and HEV
footprint. TASK-260715-2xx2tk therefore depends on TASK-260715-2jatnd; this prevents
an engine from passing on an isolated memory number that cannot fit the provider.

## 2026-07-15 — Diagram render validation environment anomaly

Both focused DOT diagrams were written, but the installed Graphviz 14.0.4 binary
exits before parsing because `/opt/homebrew/opt/libtool/lib/libltdl.7.dylib` is
missing. DOT sources and the exact failure log are attached. No rendered-image
validation is claimed, and repairing Homebrew is outside this planning-only run.

## 2026-07-20 — Published v0.1.0 is the release baseline, not local dist output

TASK-260715-1fv4z1 verified that all shipped source, test, packaging, and workflow
files are unchanged between signed tag v0.1.0 and current HEAD. The ignored local
`dist/ReluxProxy-v0.1.0-universal.dmg` is not byte-identical to the GitHub release
and lacks a stapled notarization ticket. The published 1,775,722-byte DMGs hash to
`5159c07c25f9c46df33462d256cab8a10eb79d677ad2e9b182e9e4188363c20d`, pass
stapler and Gatekeeper validation, and have provenance evidence. Migration and
regression work must use the signed tag plus published assets as the immutable
baseline; local ignored output is diagnostic only.

## 2026-07-20 — New Apple targets use Tuist 4.202.5, iOS 18, and macOS 15

TASK-260715-3r0993 selected exact repository-local Mise pin `tuist = "4.202.5"`,
new deployment targets iOS 18.0 and macOS 15.0, and explicit Xcode selection in
CI. The shipped SwiftPM product remains a separate macOS 14.0 lane. The support
floor is driven by executable test coverage, not the oldest compiling API:
GitHub's macOS 14 runner entered deprecation on July 6 and becomes unsupported
November 2, while maintained macOS 15 runners provide macOS 15 execution and
iOS 18.6 simulators. Local physical baselines are iPhone 11/iOS 26.5 and an M3
Max Mac/macOS 26.5; an iPhone 15/iOS 18.6.2 is the minimum-iOS physical lane but
its developer disk image mount must be repaired under Gate P0 before support is
claimed. GitHub is scheduled to change the macOS 26 runner default from Xcode
26.5 to 26.6 on July 21, so workflows must select `/Applications/Xcode_26.5.app`
until the upgrade matrix promotes a new pin.

## 2026-07-20 — Legacy preservation now fails closed on identity drift

TASK-260715-14lk3y added a repository-owned preservation contract, SHA-256
baseline, semantic regression guard, and negative mutation tests without
vendoring or modifying the legacy repository. The guard verifies the signed
v0.1.0 lineage, complete product-bearing source and release bytes, macOS 14
SwiftPM product, bundle/default/system-SSH identities, universal packaging,
Developer ID identity, stable `ReluxProxy.dmg`, and separation from exact paths
reserved for future generated targets. A read-only detached v0.1.0 reference
clone and a disposable packaging clone passed `swift test` (4/4), `swift build`,
ad-hoc `make app`, universal slice inspection, `make dmg`, codesign verification,
and DMG checksum verification. No incompatibility or cross-repository ownership
decision was required; any baseline update still requires the separate approved
legacy migration or retirement record.

## 2026-07-20 — Shared core now compiles without the gated workspace

TASK-260715-2nfz7w established three SwiftPM products at the ADR-016 floors:
pure `ReluxTunnelCore` plus the explicitly named iOS and macOS NetworkExtension
adapter modules. Only the adapter modules import NetworkExtension, both thin
composition roots delegate lifecycle and version routing to one shared core
actor, and their protocol-based initializers run through the same Swift Testing
contracts without generated targets or Gate P0 signing. The iOS adapter also
passes a generic arm64 iOS 18 build with signing disabled. Packet, SSH, upload,
internal SOCKS, lifecycle, clock, logging, metrics, cancellation, and memory
pressure are interfaces only: numeric limits remain injected, the SSH engine
remains ADR-014/TASK-260715-1gjxer work, and no route, DNS, relay framing,
profile persistence, Keychain, UI, concrete provider subclass, or future
app-message snapshot semantics were implemented. The M0 provider message
surface intentionally supports only a version query at protocol version 1;
later message kinds require their owning lifecycle specification.
