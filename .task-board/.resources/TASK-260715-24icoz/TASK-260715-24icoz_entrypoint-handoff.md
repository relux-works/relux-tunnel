# Accepted relay entrypoint handoff

TASK-260715-2ywde4 is reviewer-accepted done in commit 58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096, pushed and synchronized with origin/main.

Consume the accepted boundaries:
- exact supported executable modes are identity and stdio with protocol version 1;
- identity is canonical, bounded, and bound to the manifest-selected target tuple, size, SHA-256, and exact executable bytes;
- release tooling uses the pinned Go 1.26.5 and Syft inputs, isolated no-network build roots, deterministic metadata, and four declared targets;
- rootless operation, no listeners, no children, no runtime files, fixed diagnostics, and stdout separation are mandatory;
- native Darwin arm64 and Rosetta Darwin amd64 execution are locally proven; native Intel and Linux runtime rows must remain honest and must be exercised on an approved fixture rather than inferred;
- do not sign, notarize, create universal binaries, upload remotely, or hardcode a new final policy value.

For this task, produce exactly four bundle-ready assets, inspect formats and machine types, record minimum runtime, linkage, strip/debug policy, sizes and the explicit bundle budget, retain reproducibility and identity evidence, and exercise every baseline that is actually available. If a required runtime fixture is unavailable and no accepted emulation or existing CI fixture can prove AC3, stop with exact evidence rather than claiming execution.