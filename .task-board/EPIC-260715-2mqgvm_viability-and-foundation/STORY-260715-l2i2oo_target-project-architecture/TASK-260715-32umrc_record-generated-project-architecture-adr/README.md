# Record the generated-project architecture ADR

## Description
Synthesize the approved gate results, current-state inventory, generator policy, deployment targets, and relay toolchain into the binding target and dependency architecture for the generated workspace.

## Scope
In scope: target graph; product and bundle ownership; host-to-extension embedding; ReluxTunnelCore boundaries; platform adapters; native dependency direction; harness and relay targets; configuration and scheme matrix; signing-input seams; versioning; generated versus checked-in files; test ownership; migration sequencing. Out of scope: implementing the workspace, detailed packet or SSH algorithms, release-pipeline design, and changing Gate A0 or P0 conclusions.

## Acceptance Criteria
1. A TASK-ID-scoped ADR contains a focused target/dependency diagram and lists all required products, targets, packages, schemes, and configuration variants. 2. Dependency arrows are acyclic: containing apps manage configuration, providers own live state, platform adapters remain thin, and shared core does not import application UI. 3. The ADR defines generated versus source-controlled artifacts, identifier injection, signing behavior with and without credentials, dependency pins, version propagation, and test placement. 4. Legacy SwiftPM preservation and later retirement boundaries are explicit. 5. Every downstream project task traces to an ADR section, and Gate A0 or P0 constraints are incorporated without reinterpretation.
