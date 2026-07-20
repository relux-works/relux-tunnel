# TASK-260715-lovbdz rework 01 results

Date: 2026-07-20
Role: developer

## Implemented changes

- `RuntimeStartRequest` validates the nested `TunnelConfigurationReference.schemaVersion` and deterministically rejects schema 0 and 2 with `unsupportedSchemaVersion`.
- `RuntimeLifecycleSnapshot` includes `routeState` in fail-safe capability projection, so a future route state decodes as `unknown` with TCP, safe DNS, UDP, routes-installed, and health all false.
- `RuntimeDiagnosticsSnapshot` decodes absent aggregate collections to the documented empty defaults while keeping generation and sequence required and rejecting explicit `null` values.
- Runtime message documentation now states nested-version validation, route-state fail-safe projection, and diagnostics required/default behavior.

## Added regression coverage

- Old and future nested configuration-reference schema versions under a current outer start-request schema.
- Future lifecycle route-state projection with every capability asserted false.
- Missing diagnostics aggregate collections, missing required generation, and explicit-null aggregate rejection.

## Verification

- `swift test --filter RuntimeMessageCodecTests`: 15 tests in 2 suites passed.
- `swift-format lint --recursive Sources Tests Package.swift`: passed with no diagnostics.
- `make validate-core`: core boundary check passed; native dependency verification passed; 183 tests in 21 suites passed; post-test `swift build` passed.
- `git diff --check`: passed.
- `task-board validate`: passed.

Full validation log: `TASK-260715-lovbdz_validate-core-rework-01.log`.
