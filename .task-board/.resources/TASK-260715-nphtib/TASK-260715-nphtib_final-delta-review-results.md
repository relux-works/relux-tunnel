# TASK-260715-nphtib final delta review

## Verdict

ACCEPTED at signed and pushed revision 069e23bdbbef71be194762d275b003a40a6cfc72.

The prior independent clean-clone review already accepted the full generated-project architecture matrix: exact macOS target graph, deterministic generation, unsigned Debug and Release builds, actual provider adapter plus HEV and libssh2 linkage, relay integrity, fixture and dynamic-loader absence, system-only linkage, legacy preservation, 443-test coverage, strict lint, and build-host safety. Its only blocking finding was the scheduler-count race tracked by BUG-260819-34ikhl.

BUG-260819-34ikhl is accepted done. Commit 069e23b is signed, is exactly HEAD and origin/main, and has parent 7dc73ac6e7325f86a4a178a0558619f0fc9d1490. The scoped code delta changes only Tests/ReluxTunnelHarnessTests/HarnessTests.swift.

## Independent focused gates

| Gate | Exact command | Exit | Result |
| --- | --- | ---: | --- |
| Commit signature | git verify-commit 069e23bdbbef71be194762d275b003a40a6cfc72 | 0 | Valid ECDSA signature |
| Pushed revision | git merge-base --is-ancestor 069e23bdbbef71be194762d275b003a40a6cfc72 origin/main | 0 | Commit is on origin/main |
| Focused regression | swift test --filter cancellationCleanup | 0 | 50 parameterized cases passed; 1 test in 1 suite; 7s |
| Strict formatting | swift format lint --recursive --strict Sources Tests App Probes Package.swift Project.swift Workspace.swift Tuist.swift | 0 | Clean; 3s |
| Architecture boundary | make check-core-boundaries | 0 | Valid; 1s |
| Working diff | git diff --check | 0 | Clean |
| Scoped committed diff | git diff --check 7dc73ac6e7325f86a4a178a0558619f0fc9d1490..069e23bdbbef71be194762d275b003a40a6cfc72 | 0 | Clean |
| Board integrity | task-board validate | 0 | Valid before verdict attachment |
| Safety token scan | Added harness-test lines scanned for NetworkExtension, preference, tunnel, route, DNS, signing, installation, and launch operations | 1 | No forbidden match; rg exit 1 is the expected no-match result |

## Review findings

The fix removes the 10,000-yield pseudo-timeout and uses actor-isolated pending, ready, and terminal readiness states. Waiter registration, completion, and cancellation are serialized; continuations are removed before resume; late waiters receive the terminal result. Readiness is published only after directory, socket, and managed-task ownership. The focused test retains exit 143, empty output, complete directory and socket removal, and exactly one managed-task cancellation.

The accepted bug evidence additionally includes loaded 50-case signal, startup-failure, and cancellation variants, repeated clean 446-test full suites, clean coverage, formatting, boundaries, diff, and board validation. This closes the sole earlier rejection without changing production or generated-project inputs, so the prior full matrix remains applicable.

No signing, installation, application or provider launch, NetworkExtension preference save, VPN activation, route mutation, or DNS mutation was run or added. The reviewer made no code changes and supplied no commit acknowledgement.


## Architecture diagram validation

The named Graphviz dependency-plan source was checked read-only with dot -Tdot diagrams/TASK-260715-32umrc_target-dependency-plan.dot -o /dev/null; exit 0. Its declared arrow semantics are consumer to dependency or containment, and the macOS chain remains ReluxProxyMacTunnel to ReluxTunnelMacOSAdapter, then to ReluxTunnelLibSSH2Adapter, ReluxTunnelNativeAdapter, and ReluxTunnelCore, with the verified relay resource bundled by the provider. Deferred iOS nodes remain explicitly dashed and deferred. No diagram change was needed.
