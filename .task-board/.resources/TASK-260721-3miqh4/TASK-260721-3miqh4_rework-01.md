# Rework 01: DNS runtime policy evidence

Address every blocking finding in `TASK-260721-3miqh4_review-verdict.md` without weakening ADR-022, inventing evidence, or touching production runtime code.

1. Correct the DNS-over-TCP wire accounting. A maximum 65,535-byte DNS message needs its two-byte length prefix plus parser/connection accounting. Add exact maximum-wire success and one-byte-over rejection fixtures and cross-field validation vectors.
2. Define M1 and M2 state-specific timing equations. Account explicitly for UDP/relay phases, same-endpoint TCP fallback, later serial endpoint promotion, already-ready connections, dispatch allowance, and the one logical deadline. Add valid and invalid boundary vectors.
3. Replace labelled or tautological reliability results with an explicit transaction-owner/event-trace simulation. Exercise both IPv4-to-IPv6 and IPv6-to-IPv4 orderings, cancellation/tombstone/late-response races, duplicate delivery detection before deduplication, all M2 fallback trigger classes, malformed no-shopping, same-endpoint TCP, later-endpoint promotion, and exact terminal/attempt counts.
4. Replace hard-coded cleanup zero with observed ownership counters for transactions, queue bytes, reservations, tombstones, and connections. Prove cleanup after cancellation, failure, late data, and repeat runs.
5. Do not authorize production timing or memory values from local Python/RSS evidence alone. Derive them from accepted ADR-009 residual component accounting and controlled SSH direct-tcpip evidence. If those accepted inputs do not exist because SSH engine/contract selection is still a human gate, preserve the measurements only as non-authoritative candidates, identify the exact blocking tasks/decision, and stop the line with an accountable evidence packet instead of claiming acceptance.
6. Update report, policy JSON, harness, all raw runs/summary/archive, ADR/spec/README/logbook, and every downstream precondition copy atomically. Re-run privacy scans; no host, account, resolver, query, or secret identifiers may enter versionable artifacts or spawn-log outcomes.

Use only Codex Sol high. Do not delegate or use Claude.
