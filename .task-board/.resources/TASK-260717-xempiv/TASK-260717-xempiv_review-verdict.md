# TASK-260717-xempiv review verdict

Date: 2026-08-30
Role: reviewer
Change Request: `CR-TASK-260717-xempiv-1`, revision 1
Candidate tree: `556a495833c665aa42553db8aeaee806749f2041`
Verdict: **ACCEPTED**

## Scope and candidate integrity

- The board patch materialized with SHA-256
  `ec694481652ae77071133561542739de8989cd49e320854f1aae3a57f2b79335`,
  matching the Change Request record.
- All 12 changed working-copy paths matched their candidate-tree Git blob IDs;
  mismatch count was zero.
- Review was read-only. No repository source, project, documentation, or test
  file was modified by the reviewer.

## Independent gates rerun by the reviewer

| Gate | Exit/result | Evidence |
| --- | --- | --- |
| Tool readiness: task-board, git, Xcode 26.5, Swift 6.3.2, make, mise, plutil, codesign, otool | `0` | `.temp/TASK-260717-xempiv/tool-readiness-01.log`, `tool-readiness-02.log` |
| Workspace generation and exact Sparkle resolve | `0` | `.temp/TASK-260717-xempiv/workspace-generate-review-01.log`; checkout HEAD/tag are `b6496a74a087257ef5e6da1c5b29a447a60f5bd7` / `2.9.4` |
| Shell syntax and plist/entitlement lint | `0` | direct reviewer command transcript |
| Canonical Apple `swift format lint` on changed Swift | `0` | `.temp/TASK-260717-xempiv/swift-format-review-01.log` |
| Focused hosted `ReluxProxyMacTests` | `0`; 15 tests in 1 suite | `.temp/TASK-260717-xempiv/focused-tests-review-01.log` |
| Full `ReluxProxyMac` scheme tests | `0`; host 15/15 and provider 5/5 | `.temp/TASK-260717-xempiv/full-macos-tests-review-01.log` |
| Workspace foundation validation | `0` | `.temp/TASK-260717-xempiv/workspace-validate-review-01.log` |
| Release Sparkle integration smoke | `0` | `.temp/TASK-260717-xempiv/sparkle-smoke-review-01-driver.log` and `.temp/TASK-260717-xempiv/sparkle-smoke-review-01/` |
| Changed-scope private-key/signature marker scan | `rg` exit `1`, meaning zero matches | `.temp/TASK-260717-xempiv/private-material-scan-review-01.log` |
| `task-board validate` | process exit `0`; printed 3 parent-status mismatches | `.temp/TASK-260717-xempiv/task-board-validate-review-01.log` |
| Exact base-to-candidate `git diff --check` | `2`; one trailing space in byte-identical upstream Sparkle LICENSE line 37 | `.temp/TASK-260717-xempiv/exact-cr-diff-check-review-01.log` |

The exact-diff whitespace result is non-blocking: the only finding is in the
vendored Sparkle 2.9.4 license, whose SHA-256 is deliberately byte-identical to
the upstream tag. Changed Swift passes the repository's canonical formatter.
The board mismatches are board aggregation state, not candidate behavior; one is
this hard-dependency-gated Story and two are unrelated Stories.

Discarded diagnostics are not acceptance evidence: the first hash loop used the
zsh-special `path` variable and exited 127; two early secret scans were invalid
(one source-identifier false positive, one `rg` option parse failure); and the
Homebrew `swiftformat` command exited 1 because it is a different, unconfigured
formatter from the repository's Apple `swift format` gate.

## Acceptance-criteria review

1. `ReluxProxyMac` alone declares the exact remote Sparkle 2.9.4 product. The
   Release app links and embeds Sparkle 2.9.4 for arm64 and x86_64; the packet
   tunnel provider has zero Sparkle linkage or updater/helper content.
2. The built plist contains the canonical HTTPS appcast URL and approved
   32-byte public Ed25519 key, signed-feed and pre-extraction verification, and
   no private material. The exact package source recognizes every selected
   Sparkle key.
3. `main.swift` is the production call site. It constructs a retained
   `ReluxProxyAppDelegate`, which retains `ReluxProxyUpdaterLifecycle`, which
   retains one real `SPUStandardUpdaterController`. Normal launch selects
   `startingUpdater: true`; hosted tests select false. The deterministic test
   constructs the real controller without network installation and resolves the
   production feed URL.
4. Host entitlement sources retain the approved five-key boundary: sandbox,
   network client, system-extension install, Network Extension, and only the
   Sparkle `-spks`/`-spki` Mach names. Provider entitlements remain Sparkle-free.
   Both built host and provider have Hardened Runtime. Inside-out ad-hoc nested
   signing passes `codesign --verify --deep --strict`; this proves structural
   signability without Apple secrets, not Developer ID or notarization.
5. Documentation explicitly requires orderly tunnel stop and authoritative
   inactivity before replacement, then separate post-relaunch system-extension
   activation/replacement with approval/failure/restart handling and no automatic
   VPN reconnect. It explicitly says these behaviors were not exercised here.

## Negative evidence

The shipped negative tests drive production resolver/policy entry points and
reject absent feed metadata, HTTP feed URLs, parameterized feed URLs, absent
public keys, malformed/short public keys, and test-host updater start. The
producer's attached spawn log additionally records two narrowing mutants rerun
with xcodebuild: admitting HTTP and admitting a one-byte key each made its named
test fail with exit 65 before byte-for-byte restoration. The reviewer did not
repeat source mutants because this role is read-only; the reviewer independently
reran both final test suites and inspected the production call chain.

## Residual physical gates

No update was installed, no updater network check was intentionally started, no
VPN was enabled, and no route/DNS/system-extension activation was performed.
Developer ID signing, notarization/stapling, a published signed appcast, orderly
tunnel stop during an actual replacement, post-relaunch system-extension
activation/replacement, approval/restart handling, and prevention of automatic
VPN reconnect remain downstream physical-validation gates. No claim is made
that those gates passed on this machine.
