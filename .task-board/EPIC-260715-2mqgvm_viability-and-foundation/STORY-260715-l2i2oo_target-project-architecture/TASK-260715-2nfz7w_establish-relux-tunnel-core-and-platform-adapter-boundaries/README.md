# Establish ReluxTunnelCore and thin platform-adapter boundaries

## Description
Create the shared Swift package and minimal provider adapter seams defined by the architecture ADR so packet, SSH, relay, lifecycle, memory, and diagnostics work can be implemented once and injected into both Apple providers.

## Scope
In scope: package products and modules; platform-neutral endpoint, configuration, metrics, lifecycle, clock, logging, and cancellation contracts; adapter protocols for packet flow and provider lifecycle; dependency injection; Swift Testing target; compile-only provider composition roots. Out of scope: concrete packet bridge, SSH engine, relay protocol, profile persistence, Keychain implementation, route policy, UI, and speculative abstractions not required by supplied specifications.

## Acceptance Criteria
1. ReluxTunnelCore builds independently of application UI and does not import platform-only frameworks outside explicitly named adapter modules. 2. iOS and macOS providers have thin composition roots that adapt Network Extension lifecycle and packet-flow surfaces to shared contracts. 3. Dependency direction prevents shared core from reaching into containing apps or generated target state. 4. Swift Testing contract tests prove both provider adapters satisfy the same lifecycle and version-message behavior. 5. Package and module documentation maps every contract to a supplied M0 or later specification and avoids implementing future feature semantics.
