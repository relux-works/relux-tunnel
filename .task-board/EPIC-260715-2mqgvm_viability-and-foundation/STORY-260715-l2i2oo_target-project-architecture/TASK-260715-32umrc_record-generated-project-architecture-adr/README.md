# Record the generated-project architecture ADR

## Description
Synthesize the current-state inventory, generator policy, deployment targets, relay toolchain, and the approved macOS-only prototype decisions into the binding target and dependency architecture for the generated workspace. macOS host and packet-tunnel targets are the P0 scope; iOS targets are planned as a deferred extension of the same graph and are not built on this path. Gate A0 is deferred and is not an input.

## Scope
In scope: target graph; product and bundle ownership; host-to-extension embedding; ReluxTunnelCore boundaries; platform adapters; native dependency direction; harness and relay targets; configuration and scheme matrix; signing-input seams; versioning; generated versus checked-in files; test ownership; migration sequencing; the deferred-iOS extension points. Out of scope: implementing the workspace, building iOS targets, detailed packet or SSH algorithms, release-pipeline design, reinterpreting the macOS Gate P0 conclusion, and reopening the deferred Gate A0.

## Acceptance Criteria
1. A TASK-ID-scoped ADR contains a focused target/dependency diagram and lists all required products, targets, packages, schemes, and configuration variants for the macOS-only P0 scope plus the deferred-iOS extension points. 2. Dependency arrows are acyclic: containing apps manage configuration, providers own live state, platform adapters remain thin, and shared core does not import application UI. 3. The ADR defines generated versus source-controlled artifacts, identifier injection, signing behavior with and without credentials, dependency pins, version propagation, and test placement. 4. Legacy SwiftPM preservation and later retirement boundaries are explicit. 5. Every downstream project task traces to an ADR section, and the recorded macOS Gate P0 constraints are incorporated without reinterpretation.
