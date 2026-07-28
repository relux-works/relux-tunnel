# TASK-260721-2ohf99 rework-02 semantic validator rules

These rules are binding implementation inputs from
`TASK-260715-2kchi0`. JSON Schema 2020-12 enforces closed shapes and local
conditionals; the validator/reporter must enforce the cross-row, arithmetic,
filesystem, ordering, and content relationships below without inventing policy.

1. Recompute RFC 8785 row configuration, run, repetition, candidate,
   comparison-group, and immutable-manifest hashes from the exact protocol
   projections. Before hashing, reject duplicate keys and every numeric token
   outside the closed schema-v1 subset: plain base-10 integers matching
   `0|-?[1-9][0-9]*` and inclusively bounded by
   `-9007199254740991...9007199254740991`. This rejects negative zero,
   decimal/exponent notation even when JSON Schema treats it as an integer,
   unsafe integers, non-finite values, and any post-parse rounding. Reject
   missing, extra, coerced, unsorted, or hash-mismatched inputs. Hash exactly
   the JCS UTF-8 bytes: a BOM, trailing LF/CR, record separator, whitespace, or
   any other byte after the serialized JSON value is a mismatch. The regression input
   `TASK-260715-2kchi0_test-m3-jcs-hashes.sh` must accept the corrected positive
   fixture; reject schema-valid unsafe-positive, negative-zero, decimal, and
   exponent controls before hashing; reject the symmetric unsafe-negative
   control; and reject the otherwise byte-identical newline-inclusive mutation.
2. A comparison group is constant across all paired seeds, repetitions, and
   metric names. Its projection excludes run ID, repetition index, seed,
   baseline run ID, metric name, execution order, result, timestamp, and review
   state. Candidate IDs bind the exact named parameter/policy values.
3. Require byte-order-sorted unique candidate IDs and parameter names; exact
   candidate-count equality; unique ordered pair IDs; one baseline/candidate
   pair per planned seed/repetition/candidate; matching device, row, workload,
   impairment, execution block, and logical raw sample ownership; no duplicate,
   cross-group, missing, or post-result-added candidate.
4. Recompute every signed absolute and PPM effect, median/MAD/min/max, 10,000
   paired SplitMix64 bootstrap replicates, bounds, and classification. Enforce
   the same pair-index vector for absolute and PPM axes, `lower <= upper`, fixed
   units/directions, zero-baseline unavailability, and no overflow/saturation or
   implementation-specific rounding.
5. Reduce exact coverage to `(20*m-1)/(20*m)` and recompute zero-based ranks
   `floor(10000/(40*m))` and
   `ceil(10000*(1-1/(40*m)))-1`. For m=3 require exactly `59/60` and
   `83/9916`; no PPM approximation is accepted.
6. Recompute latency median/p95/p99 from the operation samples using the fixed
   integer nearest-rank rules. An unavailable triplet must use one explicit
   unavailable object; an available triplet must contain all three summaries.
7. Reconcile every metric, counter, gate, status/reason/exclusion, privacy,
   capture authorization, authority, review, and accepted-update lineage field.
   Production authorization requires concrete independent reviewer/time, all
   sixteen available per-metric comparisons/classifications, stable group,
   candidate count, exact coverage/ranks, nonempty immutable lineage, empty
   blockers, non-provisional authority, DNS permission, and every safety gate.
8. Resolve logical artifact references beneath the bundle root without symlink
   or traversal escape; verify uniqueness, existence when applicable, byte
   length, SHA-256, authorization, custodian, redacted derivative, privacy,
   retention, and no unreferenced files or prohibited/local identifiers.
9. Require `utcEnd > utcStart`, reviewed time not before row end, ordered
   monotonic/fault windows, events within the row, valid impairment restoration,
   exact schedule/matrix membership, legal exclusion/rerun linkage, and
   preservation of every pass, red, invalid, unavailable, failed, and rejected
   candidate row.

The schema fixtures attached to the protocol task are mandatory regression
inputs. They do not authorize benchmark execution or select a production value.
