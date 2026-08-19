# TASK-260715-d6x51z reviewer verdict

## Verdict

CHANGES REQUESTED. Route to `to-dev`.

## Blocking discrepancy

The task-specific authoring contract requires documentation to clearly prohibit signing and Gate P0 execution on this build host, and the reviewer contract requires README/CONTRIBUTING consistency. `docs/generated-workspace-foundation.md:16-25` correctly says this host is build-only, must not sign, and must not run the Gate P0 probe. However:

- `README.md:132` publishes `Probes/macOSPacketTunnelProbe/Scripts/build-and-inspect.sh` without a dedicated-host-only warning and describes its signed archive output.
- `docs/build-host-safety.md:12-25`, despite being named as the operational safety authority, prohibits lifecycle and network mutations but does not explicitly prohibit signing or running the signed Gate P0 probe.
- `CONTRIBUTING.md:38-45` prohibits installation/lifecycle/network mutations but likewise does not explicitly prohibit signing.

This leaves an actionable signing ambiguity across the developer entry points even though the canonical workflow itself is correct.

## Exact requested changes

1. Amend the README probe row so the command is explicitly dedicated-host-only and prohibited on this build host, or replace the unqualified invocation with a link to the dedicated-host runbook/gate.
2. Add signing and signed Gate P0 probe execution to the explicit local prohibitions in `docs/build-host-safety.md`.
3. Add the same no-signing rule to `CONTRIBUTING.md`, preserving the dedicated-host gate and preflight requirements.
4. Re-run link validation, documentation safety scans, `git diff --check`, the credential-free command-contract test, and `task-board validate`.

## Accepted evidence

- Current code revision: `d18847cd6d7f3b84bdd807eddbca37d9259945de`; the documentation-only delta was checked against `Makefile`, `Project.swift`, `Package.swift`, native/relay manifests, the generated-project ADR, and accepted `TASK-260715-nphtib` evidence.
- All 21 required ownership rows are present: four generated targets, fifteen SwiftPM targets, and two relay executables; mechanical completeness check exited 0.
- Six active schemes and Debug/Release configuration claims match `Project.swift`.
- Every documented Make target parsed with `make -n`; exit 0.
- Local Markdown link validation exited 0.
- Graphviz validation of `diagrams/TASK-260715-32umrc_target-dependency-plan.dot` exited 0.
- `./scripts/tests/test-credential-free-validation.sh` exited 0.
- `swift test --filter ReluxTunnelHarness` exited 0: 13 tests in one suite passed.
- The documented inline harness smoke exited 0 and redacted the profile reference.
- `git diff --check` exited 0.
- `task-board validate` exited 0 before verdict mutation.
- Corrected fenced-example safety scan exited 0; documentation-delta credential-payload/private-signing-path scan exited 0.
- An initial broad token scan exited 1 because it matched the required prose prohibition `startVPNTunnel`; this was a scanner false positive, not a documentation failure, and was replaced by the scoped checks above.
- No signing, credential inspection, installation, app/provider launch, VPN preference save/activation, route mutation, or DNS mutation was performed. No commit was made and no `commit_ack` was supplied.
