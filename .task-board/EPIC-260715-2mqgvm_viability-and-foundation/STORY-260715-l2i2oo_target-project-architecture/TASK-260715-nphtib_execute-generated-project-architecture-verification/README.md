# Execute the generated-project architecture verification matrix

## Description
Independently run and review the foundation validation matrix on a clean environment, including generated target graph, dependency direction, Apple builds, native fixture linkage, harness lifecycle, relay artifacts, and legacy regression. Produce the evidence needed to accept the story architecture.

## Scope
In scope: clean-checkout generation; project and scheme enumeration; iOS simulator and macOS builds; signing-disabled device build where supported; Swift Testing; native archive inspection; harness cancellation; relay target matrix; legacy SwiftPM and packaging regression; deterministic second generation. Out of scope: fixing failures, physical Gate P0 device testing, packet or SSH matrices, release signing, and feature acceptance.

## Acceptance Criteria
1. A TASK-ID-scoped result matrix records environment, tools, SDKs, source revision, commands, durations, artifacts, and pass or fail for every foundation validation row. 2. The enumerated target graph and dependency inspection match the architecture ADR exactly. 3. A second clean generation is drift-free and all credential-free builds and tests pass. 4. Native linkage and nested target inspections find no missing architecture, disallowed dynamic dependency, wrong bundle relationship, or secret material. 5. Any failure creates or references a concrete bug or rework task and this verification does not claim pass until rerun evidence is clean.
