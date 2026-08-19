# TASK-260715-mocqmr independent review contract

Perform a fresh adversarial review of the implementation and the entire task Acceptance Criteria. Do not accept based only on producer evidence or static workflow text.

## Required review

1. Inspect `scripts/relay_asset_smoke.py`, its tests, the workflow diff, relay documentation, and task outcome evidence.
2. Re-run the 13 behavioral tests with `ResourceWarning` promoted to errors, affected-code coverage, Python compilation, Actionlint, and relevant relay regressions.
3. Independently exercise the gate on a freshly selected native Darwin arm64 asset and stress the SIGTERM path. Confirm SIGTERM owns exit 130 and cannot be masked by EOF.
4. Mutate or substitute inputs to prove fail-closed behavior for at least:
   - target/host and binary architecture mismatch;
   - size/hash/manifest/self-hash drift;
   - symlink/non-regular/zero/non-executable assets;
   - stdout or stderr contamination;
   - unsupported daemon/listener/payload/version modes;
   - child process, socket/listener, runtime-file, process-residue, and cleanup failures;
   - root execution, unnamed emulation, and emulation where native evidence is required.
5. Verify JSON evidence is bounded, deterministic in schema, privacy-safe, path-free, and honest about native versus emulated execution.
6. Verify the GitHub Actions matrix uses currently valid native runner labels for all four target architectures, clean pinned inputs, exact matching target assets, `fail-fast: false`, red job semantics, and retention of exact gated artifacts/evidence. Do not treat cross-build/emulation as native proof and do not claim remote CI has run before push.
7. Confirm the implementation preserves the accepted relay/supply-chain/manifest contracts and does not introduce mutable dependencies or credentials.

## Review boundary

- The local host can prove native Darwin arm64 behavior and deterministic test/workflow contracts. The other three native rows become authoritative only when their remote jobs execute; absence of a pre-push run is not itself a defect if the CI gate is correctly implemented and remains red on missing runner support.
- This Mac is build-only. Do not sign/install/launch an app or provider, save/enable VPN preferences, call `startVPNTunnel`, or change routes/interfaces/pf/DNS. Rootless relay subprocess fixtures are allowed only when they do not alter host networking.

## Verdict

- Route to `done` only when all task ACs are satisfied with executable evidence.
- Otherwise attach exact reproduction evidence and route to `to-dev`.
