# TASK-260715-1tnjlu rework 01 outcome

Date: 2026-07-21  
Status: proposed for independent architecture review

## Reviewer findings closed

| Finding | Rework outcome |
| --- | --- |
| Unevidenced endpoint, timing, and in-flight numbers | Removed the one-to-four endpoint ceiling and every 5/5/15/10-second, 32/128-query baseline/cap from ADR-022 and the routing/DNS source of truth. Created blocking `TASK-260721-3miqh4` to select exact endpoint-count, message, byte, capacity, and timing defaults/ceilings from primary requirements, explicit memory accounting, controlled fixtures, and independent review. Production has no local fallback policy. |
| Shared reusable-connection failure under pipelining | Froze one generation-global active endpoint and one connection epoch. Epoch+upstream-ID+question ownership, tombstones, atomic terminal claims, coordinated retirement, one admission-ordered retry batch, single-manager endpoint promotion, late-epoch rejection, cache invalidation, cancellation/deadline handling, and health/teardown effects are explicit. `TASK-260715-5o6jqg` and `TASK-260715-336ljl` now contain matching implementation and fixture AC. |
| M1 one-transmission rule contradicted M2 TCP fallback | Replaced it with distinct ownership: M2 may send one UDP attempt and request same-endpoint TCP only for TC=1, pre-response size inability, UDP timeout, or typed relay failure. M1 owns TCP reuse and later endpoint promotion. Structural maximum is one UDP plus one TCP attempt per configured endpoint under one logical deadline; a valid response ends work. `TASK-260715-28jdml` now carries this contract. |

## Stable decision boundary

- Profile identity is `dnsResolver.schemaVersion = 1`, `kind = dns53`, and a
  required non-empty ordered array of canonical numeric IPv4/IPv6 endpoints.
- Endpoint `address` has no default. Omitted endpoint `port` defaults to 53.
- Resolver identity/order/port is non-secret configuration and participates in
  profile/runtime/cache/channel generations.
- The endpoint-count ceiling and all runtime numeric policy values are injected
  from the independently accepted `DNSRuntimePolicyV1`; they are not profile
  fields, ADR guesses, or implementation constants.
- M1 resolver connections are SSH `direct-tcpip`, which RFC 4254 section 7.2
  defines as the SSH server connecting to the specified target host and port.
- Ordinary post-settings DNS has no physical/system-resolver policy edge.
  Exhaustion produces bounded failure, safe-DNS loss, admission stop, and
  route/settings teardown.
- The only permitted physical DNS use is SSH-host bootstrap before routes or the
  accepted required-interface reconnect path, followed by actual SSH endpoint
  capture.

## Board and artifact impact

- Created and linked `TASK-260721-3miqh4` — Establish evidence-gated DNS profile
  and runtime limits.
- Refined `TASK-260721-33o8fc` and `TASK-260721-2raag7` to consume the accepted
  endpoint-count policy rather than hard-code one-to-four endpoints.
- Refined `TASK-260715-5o6jqg`, `TASK-260715-28jdml`, and
  `TASK-260715-336ljl` with implementable shared-connection, M2, and controlled
  fixture semantics.
- Updated ADR-022, `.spec/architecture.md`, `.spec/routing-dns-lifecycle.md`,
  `.spec/validation.md`, the task decision/research copy, downstream
  preconditions, the DOT/SVG flow, and `LOGBOOK.md`.

No vendor, public resolver, discovery protocol, or human-only product choice was
introduced. The independent reviewer remains the accountable architecture
approval boundary for ADR-022; `TASK-260721-3miqh4` is a subsequent numeric
evidence gate, not a reason to block this invariant decision.
