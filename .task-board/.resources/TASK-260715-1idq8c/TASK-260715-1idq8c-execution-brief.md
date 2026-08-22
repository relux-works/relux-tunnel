# Execution brief — build-only UI test infrastructure

- Use only the repository, accepted board resources, local simulators, and deterministic non-secret fixtures.
- This workstation is build-only: do not sign, notarize, install or launch a packet-tunnel provider, create/save/enable/start a VPN configuration, request NetworkExtension approval, or change routes, DNS, interfaces, or `pf`.
- UI-test launches must be forced into a deterministic fixture mode that cannot connect, mutate VPN preferences, or invoke system-VPN APIs. If the current product graph cannot prove that boundary, stop with exact evidence instead of launching it.
- macOS-first scope: implement the shared infrastructure needed by the macOS client. iOS may be compiled or exercised in Simulator only where the accepted task explicitly requires shared-source proof; do not expand product scope.
- Preserve existing user changes. Do not commit or push; the orchestrator owns git acceptance.
- Verify focused behavior first, then the smallest relevant build/test matrix. Attach task-scoped commands, artifacts, privacy checks, and residual risks before developer handoff.
