# Decide the HEV fork gate from Instruments evidence

## Description
Evaluate whether bridge copies or syscall rate are a material measured bottleneck after baseline profiling and record a no-fork decision or a tightly bounded callback-ingress fork approval with expected benefit, risk, notices, upstream pin, and regression plan.

## Scope
In scope: baseline and candidate Instruments traces; copy, allocation, syscall, CPU, latency, energy, and memory attribution; reproducible workload; practical materiality threshold from measurement protocol; unmodified-upstream alternatives; callback ingress concept; ABI and lifecycle risk; exact upstream commit; minimal patch boundary; licenses and notices; rebase strategy; expected tests and rollout; accountable architecture decision. Out of scope: implementing a fork, speculative optimization, private utun access, changing packet semantics, weakening bounded backpressure, or approving on microbenchmark alone.

## Acceptance Criteria
1. A TASK-ID-scoped decision references reproducible named-device traces and quantifies bridge copy and syscall contribution, confidence or noise, workload relevance, and practical materiality. 2. Unmodified upstream options such as batch, buffer, and scheduling changes are measured or ruled out before a fork is considered. 3. A no-fork outcome records why the bottleneck is not material and closes the conditional implementation task, while a fork outcome names exact callback contract, expected gain, upstream commit, patch boundary, risks, notices, rebase plan, and gates. 4. Any fork approval preserves packet boundaries, family framing, bounded drops, MTU errors, lifecycle, public API restrictions, and full regression coverage and includes accountable architecture approval. 5. The decision lists exact downstream task status, test matrices, before-and-after requirement, rollback trigger, and raw trace references and contains no traffic payloads or destinations.
