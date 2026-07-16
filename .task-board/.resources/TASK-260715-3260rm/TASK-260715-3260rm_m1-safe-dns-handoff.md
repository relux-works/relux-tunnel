# Required M1 safe-DNS handoff

Consume accepted outcomes from:

- TASK-260715-1tnjlu — exit resolver decision
- TASK-260715-1e0x1u — tunnel-owned DNS listener
- TASK-260715-5o6jqg — SSH DNS-over-TCP upstream
- TASK-260715-2hawz9 — bounded cache and fallback semantics

Integrate these components for degraded readiness and failure. Do not introduce a physical resolver path.