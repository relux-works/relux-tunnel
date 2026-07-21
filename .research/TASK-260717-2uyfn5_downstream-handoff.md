# TASK-260717-2uyfn5 downstream handoff

Date: 2026-07-21
Authority: `.research/260721_macos-self-update.md` and ADR-018
State: ready for independent review; implementation remains gated

## TASK-260717-xempiv — Integrate Sparkle updater into macOS app

- Add official SPM package `https://github.com/sparkle-project/Sparkle` at
  exact `2.9.4`; lock tag commit
  `b6496a74a087257ef5e6da1c5b29a447a60f5bd7`. Link/embed product `Sparkle`
  only in `ReluxProxyMac`.
- Instantiate host-owned `SPUStandardUpdaterController`. Do not link Sparkle
  into the packet-tunnel system extension, shared core, harness, or iOS.
- Configure the exact keys in the research report, including public
  `SUFeedURL=https://updates.relux.works/macos/appcast.xml`, signed-feed and
  pre-extraction verification, expiration `0`, consent-based scheduled checks,
  no automatic installation, and no profiling.
- Keep the host sandboxed: enable Installer XPC and its two documented Mach
  names; grant the host network client access; do not enable Downloader,
  Installer Connection, or Installer Status services.
- Preserve Hardened Runtime and archive/export re-signing for all nested Sparkle
  code. No debug/library-validation/JIT exception may be added to make signing
  pass.
- Gate installation on an orderly VPN stop. After Sparkle relaunches the host,
  separately activate/replace the embedded Network Extension system extension;
  report approval/restart state and do not auto-reconnect.
- Tests must prove exact package/configuration target boundaries and safe failure
  states without claiming physical system-extension behavior. Physical evidence
  belongs to `TASK-260715-1r48pc` and `TASK-260715-2aessv`.

## TASK-260717-1mt4e7 — Signed appcast and release assets

- Input is only the final Developer ID-signed, hardened-runtime, notarized and
  stapled DMG. Do not accept an unsigned, unstapled, pre-notarization, ZIP, PKG,
  or locally modified candidate.
- Sign final DMG bytes and the feed/release notes with Sparkle 2.9.4 tools.
  Validate `SURequireSignedFeed` and `SUVerifyUpdateBeforeExtraction` semantics;
  missing or invalid signing input fails before upload.
- Generate one feed. Stable has no `sparkle:channel`; prerelease uses exactly
  `prerelease`. Use a single globally increasing integer `CFBundleVersion` and
  macOS floor `15.0.0`.
- Publish immutable versioned DMG/release-note objects first, verify remote
  digest/length/headers, then atomically publish the signed appcast last. Feed
  and release notes are `no-store`; assets are one-year immutable. No private
  GitHub URL, credential, mutable “latest” URL, or cross-origin redirect enters
  the appcast.
- Produce offline hostile fixtures for missing/tampered feed signatures,
  release-note signatures, payload signatures, lengths, versions, channels,
  floors, and asset bytes. Prove the current installed app remains unchanged.
- Publish nothing until the human key, Apple integrity, physical lifecycle,
  privacy, and promotion gates in the research report have recorded evidence.

## Validation and privacy checks

- Verify `SUEnableSystemProfiling=NO`, no custom feed parameters, no user-specific
  query data, JavaScript off, and no analytics callbacks.
- Probe the production-shaped origin request and headers without credentials;
  confirm no private key, token, signing identity, local path, or account/machine
  identifier appears in logs or artifacts.
- Retain operational update-origin logs for at most seven days and do not join
  them to product profiles.

## Residual gates and corrections

- `TASK-260717-ziprhs` owns the human EdDSA key ceremony and escrow; no automated
  implementation task generates production key material.
- `TASK-260715-1r48pc` and `TASK-260715-2aessv` own physical clean install,
  update, approval/restart, provider-version, relaunch, interruption, and
  rollback evidence.
- Refine `TASK-260717-a8uhro` before execution: Sparkle 2 removed downgrade
  support, so test a higher-build forward rollback rather than an “explicit
  rollback channel”; enforce the product's approved host/system-extension
  identity rather than asserting Sparkle rejects every Developer ID Team ID
  change.
