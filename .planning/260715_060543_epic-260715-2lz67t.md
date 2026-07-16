# Plan: EPIC-260715-2lz67t: M2 — UDP relay and degraded mode

Generated: 2026-07-15T06:05:43+04:00
Mode: children
Elements: 5
Phases: 5

## Phase 1 (no dependencies)
- STORY-260715-18ncz1: relay-protocol-conformance

## Phase 2
- STORY-260715-3pv7qc: relay-portable-build-assets (blocked by: STORY-260715-18ncz1)

## Phase 3
- STORY-260715-2etfkl: relay-bootstrap-and-session (blocked by: STORY-260715-3pv7qc, STORY-260715-18ncz1)

## Phase 4
- STORY-260715-1nsw9p: udp-forwarding-and-associations (blocked by: STORY-260715-18ncz1, STORY-260715-2etfkl, STORY-260715-3pv7qc)

## Phase 5
- STORY-260715-2ungml: capability-and-degraded-mode (blocked by: STORY-260715-2etfkl, STORY-260715-18ncz1, STORY-260715-1nsw9p)

## Critical Path
STORY-260715-18ncz1 -> STORY-260715-3pv7qc -> STORY-260715-2etfkl -> STORY-260715-1nsw9p -> STORY-260715-2ungml (5 phases)
