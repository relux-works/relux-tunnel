# TASK-260715-p89bdj logbook

Date: 2026-07-20

## Decisions and findings

- Endpoint B is not transferred to HEV as close ownership. It remains owned by
  the bridge run and is lent exclusively until HEV's blocking main call returns.
  Stop and failure therefore request HEV quit, join the main call, then close B.
- Darwin's active SDK defines `EWOULDBLOCK` as the macro alias `EAGAIN` (`35`).
  A runtime cannot maintain truthful distinct counters for the two symbolic
  spellings. The contract normalizes both to `wouldBlock`, with separate send
  drop and receive-drain counters based on operation context.
- The accepted iOS and macOS PacketFlow adapters use a non-cancellable checked
  continuation and silently truncate mismatched packet/protocol arrays through
  `zip`; unsupported protocol entries are silently removed. This violates the
  required cancellation and observability boundary. Atomic prerequisite
  `TASK-260720-9xy8yx` was created and linked ahead of bridge implementation.
- A zero-length `SOCK_DGRAM` receive is a datagram, not stream EOF. It is handled
  as an undersized malformed frame. EOF is an explicit readiness/peer-closed or
  unexpected HEV-return event and is fatal while the run is active.
- The contract selects no MTU, buffer, batch, elapsed-time, or diagnostics-window
  value. All remain positive caller-supplied measurement inputs.
- One current Network Extension callback batch, one reverse write batch, fixed
  framing scratch space, and bounded kernel queues are the only permitted packet
  storage. There is no retry queue or overflow side buffer.

## Planning disposition

- Existing implementation, unit/fault, fuzz/allocation, and HEV integration
  tasks remain atomic and sufficient after their contract refinements.
- The only missing implementation unit was the adapter callback lifecycle task.
- No human-only decision or further research blocker remains for coding.

## Tool anomaly

The PlantUML CLI and a cached PlantUML JAR are absent from this environment, so
the two task-scoped PlantUML sources could not be rendered locally. Source-level
checks confirm one title/purpose per diagram and balanced `@startuml/@enduml`;
the validation record is attached separately. This does not alter the contract.

