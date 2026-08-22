# TASK-260715-3cv3r4 rework 01

Resolve every material finding in `TASK-260715-3cv3r4_review-results.md` without weakening the accepted contracts or safety boundary.

Required closure:

1. Drive every `SSHHostDecision` accepted/rejected outcome through the real candidate-neutral transport seam. For each rejecting decision prove zero credential lookup, signing/authentication, and channel/open work; cover cancellation/rejection cleanup.
2. Extend the deterministic test accounting to connections, observers, and callbacks, not only tasks/channels/sockets/descriptors/buffered bytes. Compare a stable baseline over bounded repetitions and prove return to baseline after success, rejection, and cancellation.
3. Add a minimal injectable matcher/spy seam around the live Keychain matcher so a fixture query passed through `LiveMacOSSystemKeychainSecurityClient` proves zero live matcher calls. Preserve the internal-only fixture constructor, exact one-item query, and fail-closed behavior; do not expose a public test API or add fallback/enumeration.
4. Replace or supplement the test-local invalid-profile probe with the narrow existing product/SPM orchestration boundary using injected Keychain and network fakes. Every invalid profile class must stop before both dependencies.

Re-run the focused coverage matrix, repeated cleanup/redaction checks, format lint, core-boundary check, diff check, and prohibited-data/live-Security scans. Update the task outcome with delta evidence and residual risk, then hand off to review.

Still prohibited: real Keychain access, real SSH/network traffic, provider signing/install/launch, VPN configuration/start, and route/DNS/interface/packet-filter mutation.
