# TASK-260721-3miqh4 downstream handoff — DNSRuntimePolicyV1

Status: corrected evidence ready for independent review; **production use is
blocked by missing accepted extension-budget and selected-SSH evidence**.

Authoritative task artifacts:

- `.research/260721_task-260721-3miqh4-dns-runtime-policy-v1.md`
- `.research/fixtures/TASK-260721-3miqh4_dns-runtime-policy-v1.json`
- `.research/raw/TASK-260721-3miqh4_measurement-summary.json`
- `scripts/dns-policy-evidence.py`

Candidate default: endpoints 4; DNS message 65,535; live owners 16; queued
wire 262,144 bytes; aggregate DNS 4,194,304 bytes; channel open 2,000 ms;
complete response 5,000 ms; relay/UDP phase 5,000 ms; dispatch allowance
1,000 ms; logical query 35,000 ms; startup readiness 10,000 ms; idle close
10,000 ms.

Candidate hard envelope: endpoints 8; DNS message 65,535; live owners 32;
queued wire 1,048,576 bytes; aggregate DNS 8,388,608 bytes; channel open
5,000 ms; complete response 10,000 ms; relay/UDP phase 10,000 ms; dispatch
allowance 2,000 ms; logical query 135,000 ms; startup readiness 45,000 ms;
idle close 30,000 ms.

Corrected local ledgers are 3,686,706 / 4,194,304 bytes and 7,635,554 /
8,388,608 bytes. Each contiguous connection buffer reserves 65,537 bytes for
the full 65,535-byte DNS message plus its two-byte prefix. Exact timing and
memory equations, equality/one-under vectors, and production-authorization
state are in the JSON.

The event-trace evidence covers both family orders, cancellation/tombstones,
late callback and duplicate detection before suppression, every M2 fallback
trigger, same-endpoint TCP, later endpoint promotion, exact attempt counts,
and observed zero ownership after cleanup. No public or physical resolver is
used.

Do not consume these candidates in production composition or profile UX.
Production remains gated on:

1. accepted `TASK-260715-1gjxer` selected-SSH evidence plus controlled
   `direct-tcpip` timing/cleanup rows;
2. accepted `TASK-260715-1pn983` cross-layer ADR-009 ledger assigning a
   residual DNS component budget; and
3. physical baseline-provider startup and footprint evidence.

ADR-022 remains Proposed and `productionAuthorization.permitted` remains false
until an independent reviewer verifies this packet and the missing inputs are
accepted. No policy value is stored in the user profile.
