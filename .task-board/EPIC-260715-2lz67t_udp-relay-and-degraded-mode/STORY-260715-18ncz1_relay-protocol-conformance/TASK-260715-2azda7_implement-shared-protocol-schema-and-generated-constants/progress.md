## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:43:57Z

## Last Update
2026-07-20T11:53:16Z

## Blocked By
- TASK-260715-111tde
- TASK-260715-18owh7

## Blocks
- TASK-260715-1y1g1u
- TASK-260715-89h7cw
- TASK-260715-516lhy

## Checklist
- [ ] Generate and compile both language bindings from one schema
- [ ] Add schema validation and generated-drift failure fixtures
- [ ] Attach regeneration commands and representative generated diffs

## Notes
TASK-260715-18owh7 decision ready for review (resource TASK-260715-18owh7_decision.md §6): add schema limits section — per-limit {name, class negotiatedWire|fixedWireConstant|localCap, width, unit, default, floor, hardCeiling}; maxFrame u32 [2048,65536] def 4096; maxUDPPayload fixedWireConstant 1472 (local lowering floor 512); maxAssociations 256 [1,1024]; perAssociationQueuedBytes client 32KiB relay 64KiB [4KiB,256KiB]; aggregateQueuedBytes/dir client 1MiB [64KiB,4MiB] relay 4MiB [64KiB,16MiB]; controlReservedBytes client 16KiB relay 64KiB [4KiB,256KiB]; dnsPriorityWeight 4:1 [1,16]; idleTimeout client 60s relay 120s [10s,600s]. Reserve hello flag bit 1, feature bit 1, msg types 0x40-0x4F (resource governance, unallocated). Validation must reject defaults outside [floor,ceiling] and fixedWireConstant edits without version/feature gate.

## Precondition Resources
- [TASK-260715-2azda7_relay-binding-input.md](file://TASK-260715-2azda7/TASK-260715-2azda7_relay-binding-input.md) — Frozen TASK-260715-111tde relay binding decision; consume the task-specific artifact and validation map
- [TASK-260715-2azda7_relay-ownership.puml](file://TASK-260715-2azda7/TASK-260715-2azda7_relay-ownership.puml) — Focused schema/generated/handwritten ownership diagram from TASK-260715-111tde

## Outcome Resources
(none)
