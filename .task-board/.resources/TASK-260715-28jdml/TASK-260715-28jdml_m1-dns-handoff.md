# Required M1 DNS handoff

Consume accepted outcomes from:

- TASK-260715-1tnjlu — exit resolver decision
- TASK-260715-1e0x1u — tunnel-owned UDP and TCP DNS listener
- TASK-260715-5o6jqg — SSH DNS-over-TCP upstream
- TASK-260715-2hawz9 — bounded cache, truncation, and fallback semantics

M2 adds relay UDP as the full-mode upstream path and must not duplicate or contradict these contracts.