# Resume architecture verification after accepted provider-graph fix

Authoritative revision: 7dc73ac6e7325f86a4a178a0558619f0fc9d1490. BUG-260819-8qf0s0 is accepted done. Re-run the complete generated-project architecture verification from a clean local clone made with --no-hardlinks at this committed revision. Do not rely on the dirty-worktree evidence from the prior failed attempt.

Required evidence:
1. Run make credential-free-validate with the legacy checkout and capture real exit/status summary.
2. Confirm exact macOS-only schemes/targets/configurations and deterministic generation.
3. Confirm unsigned Debug/Release host and provider builds.
4. Inspect the actual Release provider bundle and binary: ReluxTunnelMacOSAdapter plus HEV/libssh2 production symbols; verified relay manifest/checksum payload; no CReluxNativeFixture; no forbidden dynamic loader symbols; system-only dynamic linkage.
5. Run strict Swift formatting, coverage, task-board validation, and architecture/ADR comparison.
6. Confirm no signing, app/system-extension installation or launch, VPN preference/tunnel, route, or DNS mutation.
7. Update the task-scoped outcome with the committed-revision evidence and hand off to review only if every AC/DoD item is proven.

The current machine is build-only. Never activate a real VPN.