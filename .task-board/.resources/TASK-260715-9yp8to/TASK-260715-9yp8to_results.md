# TASK-260715-9yp8to — physical Gate P0 result

Status: **PASS — ready for review.**

## Target and signing record

- Test timestamp: 2026-08-11T11:48:09Z
- Mac: Mac15,9, arm64
- macOS: 26.5 (25F71)
- Xcode: 26.5 (17F42)
- Source revision: `9f65158f415beef5abcbeae32a007d3a266ae7df` (task worktree dirty)
- Signing identity class: Apple Development; team: `262RZ595FP`
- Host: `works.relux.tunnel.probe.mac`, 1.0 (1), profile `c0a3cd4e-77c8-475e-98e0-6deec8269810`, expires 2027-08-10
- Provider: `works.relux.tunnel.probe.mac.tunnel`, 1.0 (1), profile `ef64bcae-00ac-458f-94dc-45834429fe80`, expires 2027-08-10

No private device, account, certificate-subject, credential, signing-secret, or
raw-profile field is present in this result or its attached bundle.

## Results

- The focused App Sandbox rework is present on both signed products. The exact
  `packet-tunnel-provider` Network Extension entitlement remains unchanged;
  signed App Groups and Keychain Sharing remain absent.
- Aqua `build-and-inspect.sh`: exit 0. Four Swift contract tests pass; the
  archive succeeds; all 49 inside-out signature, nesting, architecture,
  designated-requirement, profile, and entitlement checks pass.
- Nine drift cases fail closed: identifier, Network Extension capability,
  host App Sandbox, provider App Sandbox, App Groups, Keychain Sharing,
  profile, nested product, and signature.
- Before launch, the newly installed provider had no PlugInKit match. After
  launching the sandboxed host, PlugInKit reported exactly one provider at the
  expected embedded user-Applications path.
- Ten lifecycle cycles: exit 0. Each cycle reloaded the enabled manager,
  connected, launched the provider, validated the v1 response with
  `packetForwarding=false`, stopped cleanly, terminated the host, and left zero
  provider processes. Final manager count: one.
- Controlled uninstall/reinstall at
  `/Users/iv/Applications/ReluxPacketTunnelProbe.app`: exit 0. The prior copy
  was moved to a task-scoped recoverable backup, the accepted archive was
  reinstalled and reinspected, PlugInKit again reported one provider, and the
  final lifecycle cycle passed with one manager and zero provider processes.
- Fresh coverage run: exit 0; four tests passed. `ProbeContract.swift` is
  91.80% covered (56/61 executable lines); the test bundle is 95.10% covered.
- Plist lint, shell syntax, ShellCheck, strict Swift format, log-redaction
  tests, physical-runner parser/privacy tests, and `git diff --check` pass.
- No probe crash report was created during the run. All attached focused logs
  pass the privacy scan.

## Explained intermediate failures

1. A direct background build exited 1 at signing access because that process
   could not use the login-Keychain signing secret. The approved Aqua Terminal
   seam rebuilt the same inputs and captured exit 0; no credential was read,
   exported, or weakened.
2. The first successful ten-cycle lifecycle attempt ended with runner exit 1
   after all cycles because it counted `scutil` rows using the provider ID.
   macOS 26.5 identifies this manager as `[VPN:works.relux.tunnel.probe.mac]`.
   The parser now matches that exact host configuration ID, has a provider-decoy
   regression test, and the clean ten-cycle rerun exits 0.
3. An older unsandboxed system-Applications copy from the prior attempt could
   not be removed without administrator interaction. It was explicitly
   unregistered. The accepted gate used the exact runbook-authorized user path,
   and final PlugInKit evidence contains one match at that path.
4. An extra repository-wide `swift test` check, outside the probe scope, built
   successfully but exited 1 with 377/378 tests passing: the unrelated
   `HEVUDPDatagramAdapterTests/nonterminalRelayErrorsPreserveAssociation` case
   observed zero active associations instead of one. That exact test then
   passed in 2.96 seconds. A full-suite retry stopped producing output and was
   cancelled after roughly two minutes; it exited 130 with one cancellation
   handler still pending. No claim is made that this unrelated aggregate gate
   is clean; every probe-scoped test and validation listed above exits 0.

## Acceptance criteria

- AC1 target/toolchain/revision/profile/version/timestamp record: PASS.
- AC2 nested signature/designated requirement/profile/entitlement matrix: PASS.
- AC3 manager save/reload, provider launch, v1 message, and clean stop: PASS.
- AC4 ten cycles, host termination, no stale manager/provider/crash, and clean
  reinstall: PASS.
- AC5 task-scoped repeatable runbook and redacted result bundle: PASS.
