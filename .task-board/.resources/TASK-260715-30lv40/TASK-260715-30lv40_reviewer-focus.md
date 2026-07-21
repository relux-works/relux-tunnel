# Independent review: M2 capability state and ownership contract

Review `TASK-260715-30lv40` independently against its AC and accepted M1/relay/DNS/M3 contracts.

- Treat the finite tables as executable requirements. Verify every state and each of the 32 legal transitions has consistent entry predicate, resources/generation, traffic/capability bits, safe-DNS status, reason, cleanup, retry owner, and terminal disposition; look for missing or illegal transitions.
- Prove `Full`, `Degraded`, `Failed`, `Stopping`, stale/corrupt/unknown, and reasserting-compatible projections are truthful. Full must require the complete base plus live validated relay; degraded must preserve the mandatory base while UDP is unavailable; every non-usable projection must advertise no usable traffic.
- Audit the finite reason taxonomy for completeness, stable local tokens, no remote-string injection, and unambiguous retry disposition.
- Audit generation ownership and late-event rejection across M1 runtime, M3 transport, M2 relay-attempt/active relay, and association generations. No identity or callback may cross the tuple.
- Verify retry ownership is exclusive: M2 relay-only reprobe on a healthy current base; M3 path/host/route/lane/sleep/NAT64/captive reconnect cancels M2 work before retry. UI/M4 may present immutable truth but never owns runtime state or retry loops.
- Confirm production full/degraded readiness remains false until accepted M0 composition and production-authorized DNS policy; no final engine, MTU, lane/window, timing, or overlap value is silently selected.
- Validate PlantUML sources and render both diagrams. Apply one-purpose-per-diagram review: the lifecycle state diagram must explain transitions; the ownership component diagram must explain authority boundaries. Inspect PNG readability and source/render parity.
- Check all 16 downstream preconditions, contract/spec consistency, privacy, resource-copy hashes, board validation, and diff checks. No raw spawn log or sensitive/remote-controlled data may be versionable.

Use only Codex `gpt-5.6-sol` high, no delegation and no Claude. Accept/done only if the contract is internally consistent and implementable without compensating hacks; otherwise provide exact bounded rework.
