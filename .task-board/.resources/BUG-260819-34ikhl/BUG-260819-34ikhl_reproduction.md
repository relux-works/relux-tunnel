Revision: 7dc73ac6e7325f86a4a178a0558619f0fc9d1490
Command: swift test
Exit: 1
Duration: 75.684s
Unexpected issue: ReluxTunnelHarness / signal cancellation uses signal exit code and cleans all resources / Caught error: TimedOut() at Tests/ReluxTunnelHarnessTests/HarnessTests.swift:140.
Context: authoritative clean make credential-free-validate and later swift test --enable-code-coverage both passed; failure occurred on a subsequent warm-cache timing rerun, indicating nondeterminism.
Required rework: reproduce under repetition/load, remove the race, and prove stable clean reruns.