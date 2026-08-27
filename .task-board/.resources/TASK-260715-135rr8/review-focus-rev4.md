# TASK-260715-135rr8 CR rev4 independent review focus

Review CR revision 4 as a fresh reviewer. Do not reuse the producer's conclusions as acceptance evidence.

## Blocking review gates

- Rebuild the exact working-tree OID independently through an alternate temporary Git index; verify the board CR patch bytes and that the same three-path patch applies cleanly to the Story base and current `main`.
- Audit the dual-signal lifecycle design. The unchanged 500-cycle row and 256 KiB resident-footprint maximum drawup must remain fail-closed. Lifecycle-owned release must be proven on every cycle by real post-stop state (boundary start/stop, live channels, queued batches, outstanding reads, HEV/bridge descriptor-close stages, HEV main return, and cleanup errors), not inferred from allocator page-return timing.
- Confirm the change does not simply remove the prior release requirement, retry until green, introduce arbitrary sleeps, widen thresholds, synthesize counters, or let a raw report claim success when owned resources remain live.
- Verify schema-2 raw evidence is written before a lifecycle verdict failure but is not written for a forged candidate-tree OID or bad artifact provenance.
- Independently run three sequential, non-concurrent exact-tree production matrix invocations with distinct run IDs. All three must pass, stop at 500 sessions/cycles, remain under 256 KiB maximum resident drawup, record 500/500 owned releases, and emit exact-tree/artifact-bound raw JSON.
- Independently run focused negative/pure tests, lifecycle/cancellation/pressure gates, full Swift coverage, affected-code coverage, strict format/diff/privacy/safety checks, and confirm there was no Network Extension/VPN or system networking mutation.
- Confirm the evidence continues to state unknown/unavailable fields and deferred gaps honestly and does not turn the incremental HEV/bridge budget into a whole-extension or Apple guarantee.

If accepted, attach a task-scoped verdict and leave the task at `to-review`; do not set `done` or supply `commit_ack`, because the orchestrator must first land the signed PR. If changes are needed, attach an exact actionable verdict and route to `to-dev`. Do not commit.
