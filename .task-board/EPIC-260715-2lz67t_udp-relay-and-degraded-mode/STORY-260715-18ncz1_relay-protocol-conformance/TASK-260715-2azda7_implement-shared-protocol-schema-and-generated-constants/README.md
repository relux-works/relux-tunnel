# Implement the shared protocol schema and generated constants

## Description
Create one authoritative protocol v1 schema and deterministic generators for the Swift client and selected relay language so field values, feature bits, bounds, address types, errors, and message identifiers cannot drift.

## Scope
In scope: magic and version; hello fields; envelope layout; message type and direction metadata; reserved flags; address types; feature bits; bounded error codes; negotiated and hard limit names; generated Swift and relay constants and typed metadata; schema validation; regeneration and drift checks. Out of scope: stream parsing, handshake state, association registries, socket behavior, binary packaging, protocol v2, and runtime downloading of schema or generators.

## Acceptance Criteria
1. The schema defines every protocol v1 numeric value, field width, byte order, direction, reserved range, and hard or negotiable limit with no duplicated authority in handwritten code. 2. One pinned command produces deterministic Swift and relay outputs whose public values and names match byte for byte across clean runs. 3. Schema validation rejects duplicate values, overflow, invalid ranges, missing direction or limit metadata, and backward-incompatible v1 edits. 4. Generated runtime artifacts require no generator, network access, reflection, or dynamically parsed schema in the application or relay process. 5. CI tests regenerate from scratch, compare checked artifacts, compile both bindings, and fail a deliberately stale or manually changed fixture.
