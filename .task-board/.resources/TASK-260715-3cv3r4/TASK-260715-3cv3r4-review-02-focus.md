# TASK-260715-3cv3r4 independent review 02 focus

Independently verify closure of all four findings in `TASK-260715-3cv3r4_review-results.md`; do not rely on the producer's summary.

Required checks:

- Enumerate every `SSHHostKeyDecision` case from the production contract and prove each is driven through the transport seam with the exact accepted/rejected ordering and zero downstream credential/sign/channel work on rejection.
- Inspect the connection/observer/callback accounting implementation for self-fulfilling counters. Prove success, rejection, and gated cancellation observe real fixture lifecycle transitions and return to one stable baseline across bounded repetitions.
- Pass a fixture query through `LiveMacOSSystemKeychainSecurityClient` with the injected matcher spy and prove zero matcher calls. Confirm fixture constructor and matcher are non-public and live queries retain exact one-item/no-fallback semantics.
- Prove invalid profile cases traverse the real `TunnelRuntimeCoordinator` startup composition boundary and that injected Keychain/network dependencies remain untouched; reject a test-local helper disguised as composition.
- Re-run focused tests, coverage, repeated cleanup/redaction checks, format lint, core-boundary check, diff check, and prohibited-data/live-API scans within the no-network/no-real-Keychain boundary.

No real Keychain, SSH/network, provider, VPN, route, DNS, interface, or packet-filter action is authorized. If accepted, attach a new review-02 outcome and move to `done`; otherwise return exact actionable findings to `to-dev`.
