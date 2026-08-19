# BUG-260819-8qf0s0: generated-provider-graph-omits-accepted-adapter-and-relay-edges

## Description
Project.swift generates ReluxProxyMacTunnel with only ReluxTunnelCore, while accepted generated-project ADR section 3.1 requires ReluxTunnelMacOSAdapter and verified relay resources. The green credential-free gate does not assert this dependency/resource graph, and the Release provider contains no adapter/native or relay payload.

## Scope
Add the missing provider-to-ReluxTunnelMacOSAdapter and verified relay-resource packaging edges, add a fail-closed generated-graph/linkage regression assertion, and rerun the clean credential-free matrix. Preserve the rule that CReluxNativeFixture is evidence-only and must not become a production dependency. No signing or VPN activation.

## Acceptance Criteria
Generated provider graph matches the accepted ADR; Release provider embeds/links the production adapter/native and verified relay resource contract without CReluxNativeFixture; the validator fails on missing edges/resources; clean detached-clone matrix passes.
