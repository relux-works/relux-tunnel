# TASK-260721-3miqh4 independent review verdict

Verdict: **changes requested → analysis**

The proposed `DNSRuntimePolicyV1` is not yet acceptable. The published artifacts are internally synchronized, the advertised validation commands pass, and the fixture process remained loopback-only in this review, but the evidence does not satisfy AC 1, 3, 4, or 5 strongly enough to authorize production defaults or move ADR-022 to Accepted.

## Blocking findings

### 1. Full-wire buffer accounting is one byte short and is not boundary-tested

RFC 1035 defines a two-byte TCP length prefix outside the DNS message, and RFC 5936 makes the resulting DNS-message maximum 65,535 octets explicit. A maximum framed unit is therefore 65,537 bytes. The report calls each 65,536-byte connection buffer “one full framed message” (`.research/260721_task-260721-3miqh4-dns-runtime-policy-v1.md:165-166`), while the harness fixes both buffers at 65,536 (`scripts/dns-policy-evidence.py:37-38`). The wire fixture transmits only a 30-byte response, so it cannot detect this boundary defect.

Rework: either reserve at least 65,537 bytes for each contiguous framed connection buffer and update every ledger/hash/vector/copy, or specify and prove a message-only buffer with a separately owned two-byte framing state and no unaccounted concatenation. Add exact 65,535-byte request/response, split-prefix, split-body, coalesced-frame, and partial-write fixtures.

Primary sources: [RFC 1035 §4.2.2](https://www.rfc-editor.org/rfc/rfc1035.html#section-4.2.2), [RFC 5936 §2](https://www.rfc-editor.org/rfc/rfc5936.html#section-2), and [RFC 7766 §8](https://www.rfc-editor.org/rfc/rfc7766.html#section-8).

### 2. M2 timing is omitted from the logical-deadline equation

The policy states that M2 permits one UDP attempt plus up to one TCP attempt per endpoint under one logical deadline, but validation checks only `E × (channelOpen + response)` (`scripts/dns-policy-evidence.py:145-151`; policy report lines 274-279). If the permitted UDP timeout consumes the response slice, the stated default worst path is `5 + 4 × (2 + 5) = 33 s`, not 30 s; the hard path is `10 + 8 × (5 + 10) = 130 s`, not 120 s. Relay association/session and datagram-size phases are likewise not assigned an explicit time budget. Exact-equality startup ceilings also leave no defined scheduling/dispatch allowance despite the claim that every full slice is covered.

Rework: define the UDP/relay phase deadline and whether an already-ready active TCP connection removes an open slice in every state. Encode the actual M1 and M2 worst-case equations in the validator, add invalid boundary vectors, and either add explicit overhead/slack or narrow the claim about full per-attempt slices.

### 3. Required reliability evidence is partly labelled rather than exercised

- `dualOrdered` is a closed IPv4 port followed by the IPv4 fixture (`scripts/dns-policy-evidence.py:663-664`), not ordered IPv4/IPv6 failover.
- Cancellation is a literal result dictionary (`scripts/dns-policy-evidence.py:713-719`); no owner is cancelled, tombstoned, raced with failure, or prevented from receiving a late response.
- Duplicate detection stores responses in a dictionary keyed by ID and then computes `len(dict) - len(set(dict))` (`scripts/dns-policy-evidence.py:381-397`), which is necessarily zero and would overwrite the evidence of a duplicate.
- M2 tests only UDP success, TC, and timeout followed by one TCP exchange. They do not exercise malformed/mismatched UDP, cancellation, late UDP versus TCP terminal-claim races, typed relay failure/oversize triggers, or later-endpoint TCP promotion while proving the `1 UDP + E TCP` cap.

Rework: use an explicit transaction-owner simulation with an event/callback trace rather than pre-filled counters. Exercise both dual-family orders, real cancellation/tombstone release, duplicate delivery detection before deduplication, all M2 trigger classes, malformed no-shopping, same-endpoint TCP, later-endpoint promotion, late data, and exact terminal/attempt counts.

### 4. Memory and timing defaults are not derived from the accepted extension/SSH evidence

The repository accepts only a provisional 25–30 MiB whole-extension target and requires DNS, SSH windows, HEV, relay, cache, socket buffers, and reconnect overlap to appear in the combined ledger. The report acknowledges that there is no accepted DNS slice, no selected SSH engine, and no numeric whole-provider startup SLA, then selects 4/8 MiB and 2/5-second open/response values from percentages and raw loopback TCP measurements. That is not a proof that the proposed production default composes within ADR-009 or that it bounds SSH `direct-tcpip` behavior. The memory trial allocates bytearrays whose sizes come directly from the ledger, so `allocationMatchesLedger` is tautological; `liveTrackedAllocationBytesAfterCleanup` is assigned constant zero (`scripts/dns-policy-evidence.py:464-505`) rather than measured from transaction/queue/tombstone state.

Rework: provide the residual component budget from a complete accepted-extension ledger and controlled SSH channel evidence, or explicitly preserve these fields as unaccepted injected candidates and record the exact dependency that must supply the missing budget/engine/startup evidence. Instrument real harness ownership counters so cleanup-to-zero is observed, not asserted. Do not use the current Mac/Python allocation envelope as authorization for an iOS extension production default.

## Checks reproduced

- `python3 -m py_compile scripts/dns-policy-evidence.py` — pass.
- `python3 scripts/dns-policy-evidence.py --self-test-only` — 7/7 pass.
- Policy artifact verification — pass.
- Independent 5-warmup/30-repeat loopback run — pass; zero `getaddrinfo` calls and zero FD delta.
- Independent default/hard memory trials — ledger-sized allocations completed; the cleanup caveat above remains.
- `task-board validate` and `git diff --check` — pass.
- Published report/script/policy/summary/archive copies are byte-identical; all recorded raw SHA-256 values reproduce.
- Versionable task resources and every archive member were scanned for the current hostname/user path, UUIDs, private-key markers, and token patterns; no sensitive finding was detected. Synthetic loopback and reserved fixture data were not treated as real resolver/query identity.
- No production source was added or modified by this task; the disposable Python harness remains outside production modules.

## Required next handoff

Update the report, policy JSON, harness, raw runs/summary/archive, ADR/spec text, README claim, logbook, and every downstream precondition copy together. Return the task to `to-review` only after the corrected full-wire ledger, M1/M2 timing vectors, exercised reliability matrix, cleanup instrumentation, and accountable extension/SSH budget derivation are attached.
