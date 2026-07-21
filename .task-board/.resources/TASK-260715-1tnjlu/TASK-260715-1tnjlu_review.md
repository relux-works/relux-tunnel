# TASK-260715-1tnjlu — independent architecture review

Date: 2026-07-21
Verdict: CHANGES REQUESTED
Route: analysis

## Outcome

The vendor-neutral direction is sound: explicit ordered numeric per-profile DNS endpoints, M1 DNS-over-TCP through authenticated SSH, no product/system resolver default, no shell discovery, no baseline DoH, and no ordinary physical-resolver fallback all follow the accepted privacy and bootstrap invariants. No human vendor/product choice remains.

The task is not yet approvable because the proposed source-of-truth contract leaves numeric evidence and shared-connection retry semantics under-specified. These are recoverable architecture-decision issues, not a stop-the-line boundary.

## Required changes

### 1. Justify or reframe every hard numeric ceiling

The decision calls 5/5/15/10 seconds, 32 in-flight queries, hard caps of 10/10/30/60 seconds and 128 queries, and the 1–4 endpoint cardinality “accepted” without project evidence or an architectural derivation. RFC 7766 supports reuse, pipelining, one regular TCP connection, and short idle management, but explicitly does not prescribe a particular idle value or retry algorithm. The task review input requires injectable evidence baselines with justified hard caps.

Revise ADR-022 and the task outcome to do one of the following for each number:

- derive the baseline and ceiling from an accepted memory/startup/transaction budget and cite that evidence; or
- classify it explicitly as a provisional injected evidence baseline, name the concrete downstream evidence task that may change it, and avoid claiming an unevidenced range as accepted/final.

For in-flight work, include a maximum DNS message/buffer and aggregate queued-byte relationship, or cite the downstream accepted contract that bounds them, so 128 transactions cannot silently violate the extension memory budget. Explain why four endpoints are the schema ceiling or make that bound an explicitly reviewable schema safety choice.

### 2. Define deterministic shared-connection failure and endpoint promotion

The policy permits up to 32 pipelined queries on one reusable connection, then says any EOF, timeout, malformed/mismatched response closes the channel and each query may advance to the next endpoint. It does not say:

- whether the active endpoint is generation-global or selected independently per query;
- what happens to every other in-flight query when one transaction closes the shared channel;
- whether those transactions retry, fail, or participate in one coordinated endpoint promotion;
- how the implementation preserves the “at most one connection” rule and prevents a retry/reopen storm;
- how late responses from the retired connection are discarded;
- how a four-endpoint startup attempt fits the stated per-open and total budget.

Freeze one implementable state rule and add corresponding controlled-fixture cases to TASK-260715-5o6jqg and TASK-260715-336ljl impact text.

### 3. Remove the M1/M2 transmission contradiction

The decision says each explicit endpoint receives at most one transmission for a logical query, while M2 is required to retry the same resolver over TCP after UDP TC, oversize, timeout, or relay failure. Scope the one-transmission rule to M1 TCP endpoint attempts, or explicitly define the permitted one UDP plus one TCP attempt and its deadline/accounting. Update TASK-260715-28jdml handoff text so it cannot implement conflicting semantics.

## Acceptance findings

- AC1: PASS. All four required policies are compared across privacy, bootstrap, reliability, UX/platform, M2/degraded compatibility, testability, and cost.
- AC2: PARTIAL. Schema, validation, port/transport, address families, migration, and fail-closed behavior are concrete; numeric evidence and concurrent failure semantics require the changes above.
- AC3: PASS as a policy proof. Ordinary post-settings DNS has only virtual ingress -> authenticated SSH/relay -> configured numeric endpoint; exhaustion revokes safe DNS and tears down settings. SSH-host DNS is separately limited to pre-route or required-interface reconnect bootstrap, with actual endpoint capture owned by the accepted runtime/routing contracts.
- AC4: NOT YET. The independent reviewer cannot approve the Proposed ADR until the recoverable gaps above are resolved; no human-only decision is requested.
- AC5: PASS. DNS implementation, routing/startup, M2 relay/degraded, M4 profile, documentation, harness, and physical leak tasks are named by concrete ID. TASK-260721-33o8fc and TASK-260721-2raag7 have usable descriptions/AC and valid dependency links; update their copied preconditions after ADR rework.

## Independent verification

- task-board validate: PASS.
- git diff --check: PASS.
- DOT render and xmllint: PASS; PNG visual inspection shows legible, unclipped bootstrap, ordinary-query, forbidden-physical-resolver, and teardown paths.
- Recorded artifact SHA-256 values: MATCH; research and task outcome decision are byte-identical.
- make validate-core: PASS; 306 Swift tests in 27 suites plus swift build and boundary/native-package checks.
- RFC checks: RFC 1035 section 4.2 supports TCP/UDP port 53 and TCP length framing; RFC 7766 sections 6–7 support reuse, pipelining, one regular connection, and ID/question correlation but leave concrete timeout/retry choices to policy; RFC 8484 documents DoH bootstrap/deadlock risks; RFC 4035 supports transparent DO/CD/AD handling; RFC 5952 supports canonical IPv6 text.

Primary references:

- https://www.rfc-editor.org/rfc/rfc1035.html#section-4.2
- https://www.rfc-editor.org/rfc/rfc7766.html
- https://www.rfc-editor.org/rfc/rfc8484.html
- https://www.rfc-editor.org/rfc/rfc4035.html
- https://www.rfc-editor.org/rfc/rfc5952.html
