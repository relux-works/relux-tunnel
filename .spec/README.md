# Relux Proxy specifications

This directory is the source of truth for the target Relux Proxy VPN product.
Implementation is partial: shared packet, provider/runtime, SSH-contract, relay,
and diagnostic components exist, but there is no shippable system-VPN target or
end-to-end release evidence. [`threat-model.md`](threat-model.md) and
[`security-claims.md`](security-claims.md) distinguish implemented components,
accepted design, and planned/evidence-gated behavior.

## Specification map

| Document | Purpose |
| --- | --- |
| [`product.md`](product.md) | Product goals, user journeys, scope, and product acceptance |
| [`architecture.md`](architecture.md) | System boundaries, components, and trust boundaries |
| [`packet-plane.md`](packet-plane.md) | Packet bridge, HEV/lwIP integration, buffering, and memory |
| [`ssh-transport.md`](ssh-transport.md) | SSH engine gates, channels, lane pool, windows, and rekeying |
| [`relay-protocol.md`](relay-protocol.md) | Rootless remote relay lifecycle and wire protocol |
| [`routing-dns-lifecycle.md`](routing-dns-lifecycle.md) | Routes, DNS, reconnect, and kill-switch behavior |
| [`security-privacy.md`](security-privacy.md) | Threat model, credential handling, and privacy controls |
| [`threat-model.md`](threat-model.md) | macOS-first assets, flows, adversaries, boundaries, controls, and residual risks |
| [`security-claims.md`](security-claims.md) | Approved/prohibited user-facing claims and evidence crosswalk |
| [`platform-distribution.md`](platform-distribution.md) | Apple targets, entitlements, signing, CI, and release channels |
| [`validation.md`](validation.md) | Test strategy, performance measurements, and go/no-go gates |
| [`delivery.md`](delivery.md) | Milestones, dependencies, estimates, and exit criteria |
| [`decisions.md`](decisions.md) | Accepted decisions and unresolved architecture questions |

The detailed implementation backlog is maintained in `.task-board/`. Generated
phase plans in `.planning/` are derived from that board and must not replace
these specifications.

## Requirement language

`MUST`, `SHOULD`, and `MAY` express required, recommended, and optional behavior.
Items marked **Gate** must be proven before dependent implementation proceeds.
Items marked **Open** require an explicit architecture or product decision.

## Change control

A change that affects a protocol, security boundary, platform entitlement,
failure mode, or user-visible privacy behavior MUST update the relevant spec and
the decision log in the same pull request. Board tasks MUST link the relevant
specification as a precondition resource.
