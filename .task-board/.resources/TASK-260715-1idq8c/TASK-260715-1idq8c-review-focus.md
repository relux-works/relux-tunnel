# Independent review focus

Review the complete diff and accepted task resources independently. Do not rely on producer claims.

- Confirm all five revised ACs, especially the explicit split: unsigned native macOS build-for-testing on this build host; signed native macOS runtime only in `TASK-260822-3q4grm` on the dedicated test Mac.
- Verify the fixture graph has no NetworkExtension/provider/VPN-preference/network-client path and that no real VPN/system-network action is executed.
- Re-run focused static contracts, shared Swift tests, snapshot-diff tests, workspace generation/build-for-testing, and the build-host smoke where safe. Do not sign anything.
- Inspect extracted screenshots at original resolution for orientation, clipping/layout, expected content, and black/empty rendering.
- Check the smoke script cannot report a deferred macOS runtime as a runtime success, and fails when macOS build-for-testing or iOS runtime fails.
- Audit the reported unrelated SSH full-suite flake: distinguish task regression from pre-existing/intermittent evidence; do not waive a causally related failure.
- If accepted, hand off to `reviewing` because git commit confirmation remains the orchestrator’s responsibility. If changes are needed, route to `to-dev` with exact findings.
