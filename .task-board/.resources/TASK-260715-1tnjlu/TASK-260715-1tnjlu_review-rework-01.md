# TASK-260715-1tnjlu independent review after rework 01

Date: 2026-07-21
Verdict: ACCEPTED
Route: done

This outcome is the accountable independent architecture approval for the invariant layer of ADR-022. Exact numeric DNSRuntimePolicyV1 defaults and ceilings are deliberately not approved here; TASK-260721-3miqh4 owns that subsequent evidence decision and blocks every numeric production consumer. No unresolved vendor, product, platform, or human-only choice remains in this task.

Acceptance evidence:
- AC1 PASS: explicit profile endpoints, product default, exit discovery, and tunneled DoH are compared across privacy, reliability, bootstrap, platform and UX, M2/degraded compatibility, testability, operational cost, and operator expectations.
- AC2 PASS: dnsResolver schemaVersion 1, kind dns53, ordered non-empty canonical numeric IPv4/IPv6 endpoints, port default 53, address-family and validation rules, SSH TCP and relay UDP ownership, failover, cancellation, cache generation, failure, teardown, and no-inference migration are exact. Unsupported numeric tuning was removed and production has no fallback policy until TASK-260721-3miqh4 is independently accepted.
- AC3 PASS: ordinary post-settings queries have only virtual ingress to authenticated SSH or relay to the configured numeric exit endpoint. Physical DNS is limited to SSH-host bootstrap before routes or the accepted required-interface reconnect path, with actual SSH endpoint capture; exhaustion revokes safe DNS, stops admission, and clears settings.
- AC4 PASS: this independent reviewer approval accepts ADR-022 as derived from existing accepted privacy and runtime invariants.
- AC5 PASS: concrete implementation, M4, M2, documentation, harness, and physical validation task impacts and dependency links are complete. TASK-260721-3miqh4, TASK-260721-33o8fc, and TASK-260721-2raag7 are atomic and carry usable descriptions and AC.

Prior findings are closed: all unsupported timeout, capacity, and endpoint-count values were removed behind TASK-260721-3miqh4; shared reusable TCP failure now atomically retires one epoch and coordinates one admission-ordered eligible retry batch under generation-wide endpoint promotion; M2 owns one active-endpoint UDP attempt and only enumerated same-endpoint TCP handoff triggers while M1 owns TCP reuse and later serial promotion.

Independent checks: task-board validate PASS; reviewed local Markdown links PASS; git diff --check PASS; RFC 1035, 4254, 7766, 8484, 4035, and 5952 claims verified; DOT render and xmllint PASS; original-resolution diagram inspection PASS; research, DOT, SVG, and rework resource copies byte-identical with recorded SHA-256 values; make validate-core PASS with 306 tests in 27 suites and post-test build. No project code or specification was modified by the reviewer.