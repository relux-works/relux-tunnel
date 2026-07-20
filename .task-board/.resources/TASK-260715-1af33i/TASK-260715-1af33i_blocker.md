# TASK-260715-1af33i blocker evidence

## Constraint
The adapter cannot be implemented against the reviewed common boundary because its owning prerequisite, TASK-260720-100wu6 Implement the candidate-neutral SSH transport contract, remains in backlog. The board correctly rejects the required development transition.

## Evidence
- set_status to development was rejected with TASK-260720-100wu6 as the unfinished dependency.
- Sources/ReluxTunnelCore/SSHContracts.swift remains the earlier skeleton. It has no SSHTransportFactory, SSHTransportDependencies, lifecycle and timeout policies, partial writeSome semantics, receive-window snapshot and cap, explicit rekey reasons, keepalive, stable SSHTransportError taxonomy, or schema-v1 snapshots and events.
- Package.swift has no ReluxNIOSSH adapter target or source dependency yet, which is appropriate until the common boundary lands.
- All five other direct prerequisites are accepted done.

## Failed assumption checked
The board status might have been stale while the common contract had already landed in source. Repository inspection disproved that assumption.

## Options and tradeoffs
1. Recommended: implement and review TASK-260720-100wu6 first, then re-spawn this adapter task. This preserves the candidate-neutral ownership boundary and enables compile-time conformance.
2. Add the missing common types inside this adapter task. Rejected because it takes over another task, risks candidate-specific shaping of ReluxTunnelCore, and makes later adapters and conformance work diverge.
3. Hide a parallel private contract in the candidate module. Rejected as a forced fit because it cannot satisfy common-boundary conformance and duplicates semantics.

## Exact resume condition
TASK-260720-100wu6 must reach reviewed done with its public Swift surface and tests merged into this workspace. The orchestrator can then requeue TASK-260715-1af33i for development. No product or architecture decision is needed.