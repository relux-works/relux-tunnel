# BUG-260728-3jfjkh: stabilize-provider-failure-first-callback-ordering

## Description
A reproducible race in TunnelProviderAdapter.providerDidFail lets two sequential provider-failure callbacks be admitted by unordered Tasks; the second error may win, so ProviderAdapterContractTests.providerFailureHandoff intermittently returns internalInvariant 1009 instead of the first runtimeStartupFailed 1007. Diagnose and restore deterministic exactly-once first-call semantics without weakening lifecycle cleanup.

## Scope
In scope: provider-failure callback admission/order in ReluxTunnelCore, both iOS/macOS composition roots through the shared adapter, deterministic exactly-once cancellation, focused race/repeatability coverage, full Swift suite. Out of scope: changing NSError codes, relaxing the assertion, unrelated lifecycle behavior, board replanning, product features.

## Acceptance Criteria
1. Two sequential providerDidFail calls deterministically deliver the first call error exactly once on both adapter seams. 2. Concurrent/reentrant calls remain exactly-once and do not deadlock or leak cleanup. 3. The focused providerFailureHandoff test passes at least 30 consecutive runs. 4. The complete swift test suite passes with real exit 0. 5. The fix is minimal, preserves provider-failure stop/join semantics, and is independently reviewed.
