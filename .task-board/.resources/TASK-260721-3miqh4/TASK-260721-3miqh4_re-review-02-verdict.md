# TASK-260721-3miqh4 — independent re-review 02 verdict

Verdict: **changes requested**; route to `analysis` for bounded evidence-harness
rework. This task is not accepted and ADR-022 must remain Proposed.

## What independently reproduced

- The controlled run accepted a 65,535-byte DNS message as a 65,537-byte
  DNS-over-TCP frame and rejected a 65,536-byte message.
- IPv4-failure to IPv6-success and IPv6-failure to IPv4-success each used two
  serial attempts.
- The event-trace scenarios executed cancellation/tombstones, late callbacks,
  duplicate attempts before suppression, malformed/mismatched no-shopping,
  all five M2 TCP-fallback trigger classes, same-endpoint TCP, later endpoint
  promotion, and cleanup ownership counters.
- The fresh 5-warmup/30-repeat run reported zero `getaddrinfo` calls, zero file
  descriptor delta, and zero final transaction, queue-byte, reservation,
  tombstone, connection, connection-buffer, and fixed-byte ownership.
- The candidate ledgers recompute to 3,686,706 / 4,194,304 bytes and 7,635,554
  / 8,388,608 bytes. All nine recorded raw hashes match the summary; research
  and board resource copies, including the 15-member evidence archive, match.
- Privacy scans found no absolute user path, hostname field/value, username or
  account field, UUID value, private-key marker, task-board token, or spawn-log
  member in the evidence archive.
- `productionAuthorization.permitted=false` is present in the policy and the
  summary remains candidate-only. The repository correctly leaves ADR-022
  Proposed and downstream handoffs say not to consume the values.

Primary-source checks agree with the protocol-derived claims: RFC 1035 section
4.2.2 defines the two-byte TCP length prefix outside the message length; RFC
5936 section 2 states the 65,535-octet DNS message limit; RFC 7766 requires
unique in-flight IDs on a connection and ID/question response correlation;
RFC 4254 section 7.2 says the SSH channel recipient connects to the specified
`direct-tcpip` target; and RFC 9210 supports 10 seconds only as a reasonable
idle-timeout starting point, not the other production timings.

- https://www.rfc-editor.org/rfc/rfc1035.html#section-4.2.2
- https://www.rfc-editor.org/rfc/rfc5936.html#section-2
- https://www.rfc-editor.org/rfc/rfc7766.html
- https://www.rfc-editor.org/rfc/rfc4254.html#section-7.2
- https://www.rfc-editor.org/rfc/rfc9210.html

## Blocking findings

### 1. Three timing boundary rows are tautologies, not validator vectors

`scripts/dns-policy-evidence.py:1060-1068` emits all five timing rows using
`required >= required` and `required - 1 >= required`. Those booleans cannot
fail when `validate_policy` or a ready/cold equation is wrong. Only startup and
the governing M2-cold relationship are actually passed through
`validate_policy` at lines 1033-1058. Therefore the report's claim that the
harness emits verified exact boundaries for M1-ready, M1-cold, and M2-ready is
not supported.

Bounded rework:

1. Replace the tautologies with independently specified expected values for
   startup, M1-ready, M1-cold, M2-ready, and M2-cold at both default and hard
   envelopes.
2. Exercise each corresponding validator error branch with one-millisecond-
   under mutations and assert the expected error tag. At equality, assert that
   the relationship's error tag disappears; retain overall valid equality
   vectors for startup and the governing M2-cold maximum.
3. Publish the real vectors in the machine policy, raw runs, summary, archive,
   report, validation log, and copied handoffs; remove claims based on the old
   tautological rows.

### 2. The policy verifier ignores the stop-line authorization contract

`verify_policy_artifact` at `scripts/dns-policy-evidence.py:1085-1131` checks
numeric dictionaries and calculated proofs, but it does not check
`productionAuthorization`, `adr022MayAdvanceToAccepted`, candidate status,
blocking inputs, `profileStorage`, `attemptPolicy`, `timingSemantics`,
`validationEquations`, metadata subledgers, or `wireBoundaryVectors`. A policy
with `productionAuthorization.permitted=true` can therefore pass the advertised
policy verification command. That is unsafe for this evidence gate.

Bounded rework:

1. Make verification fail closed on every authority-critical nonnumeric field,
   especially both authorization booleans and the exact blocking inputs.
2. Verify the structural attempt contract, equations, metadata subledgers, and
   wire vectors rather than merely copying them into JSON.
3. Add negative self-tests that flip/remove authority-critical fields and prove
   rejection.

### 3. Reliability counts are recorded but not asserted exactly

`simulated_reliability_matrix` at `scripts/dns-policy-evidence.py:960-992`
checks only cleanup, `udpAttempts <= 1`, TCP attempts below the broad endpoint
cap, and visible responses below a broad cap. It does not assert the claimed
trigger-specific exact attempt/transmission/terminal counts. Under-counting a
fallback, using the wrong endpoint order, omitting the promoted attempt, or
losing the expected late/duplicate callback could still pass.

Bounded rework:

1. Define an explicit expected tuple for every scenario: UDP attempts and
   transmissions, TCP attempts and endpoint ordinals, visible terminals,
   duplicate attempts, late callbacks, tombstones, epochs, and retry batches.
2. Assert exact tuples for valid UDP; malformed/mismatched no-shopping; each of
   the five fallback triggers; later promotion; late UDP; cancellation during
   TCP; cancellation/tombstone retirement; duplicate delivery; and the 16-owner
   coordinated failure/retry batch.
3. Regenerate all raw evidence, summary, archive, report, copied resources, and
   privacy/hash validation after the assertions are in place.

## Accountable dependency boundary

The producer is correct that local Python/loopback evidence cannot authorize
production values. `TASK-260715-1gjxer` — Record the M0 SSH engine selection —
is backlog and blocked by its candidate matrices; it has no accepted selected-
engine `direct-tcpip` rows. `TASK-260715-1pn983` — Record the cross-layer
memory, window, and rekey contract — is backlog and has no accepted ADR-009
residual DNS budget. Physical provider startup/footprint evidence is also a
later external gate. Direct dependency links to the first two tasks were added
during this review after checking for cycles.

Because the three findings above are recoverable evidence rework, this verdict
routes to `analysis`, not `blocked`. After that rework passes review, if the
selected-SSH and residual-budget inputs are still absent, the correct next
verdict is evidence-backed `blocked`, not `done`. Acceptance requires those
inputs, physical revalidation where assigned, production authorization, and a
new independent review.

## Commands run

```bash
python3 scripts/dns-policy-evidence.py --self-test-only
python3 scripts/dns-policy-evidence.py --verify-policy \
  .research/fixtures/TASK-260721-3miqh4_dns-runtime-policy-v1.json
python3 scripts/dns-policy-evidence.py --warmup 5 --repeats 30
shasum -a 256 .research/raw/TASK-260721-3miqh4_*.json
tar -tzf .research/raw/TASK-260721-3miqh4_evidence-bundle.tar.gz
cmp -s <research artifact> <task-board outcome copy>
task-board validate
git diff --check
```

The repository was reviewed read-only; no production or harness code was
modified by the reviewer.
