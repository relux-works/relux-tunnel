# TASK-260715-ypo7yo reviewer verdict 09

Verdict: **CHANGES REQUESTED**. Route: `analysis`.

This is recoverable contract/gate rework. It is not a Stop-The-Line external
blocker, and no portal mutation is authorized.

## Blocking finding

### F1 — the r10 conditional exception is exact in the data but not fail-closed in the validator

Revision r10 correctly models the unresolved macOS 15.0 sandbox-policy question
and keeps `X1-C1` unarmed. However, `R39` does not machine-check the exact
least-privilege contract it pre-authorizes:

- `valuesIfArmed` is checked only for non-emptiness and equality between the
  target row and conditional register. Coordinated drift from
  `["/Library/Keychains/"]` to `["/"]` passes.
- `channelsIfArmed` is checked only for membership in the target's channels and
  equality between the row and register. Coordinated drift from
  `["development", "developer-id"]` to `["development"]` passes.
- `armedBy` is checked only for the shape of an element ID. Drift from the K3
  resolution owner `TASK-260715-1uxx3i` to the unrelated existing consumer
  `TASK-260715-9yp8to` passes.

These are not cosmetic future-proofing issues. `X1-C1` is the review that makes
the exception pre-authorized. If it is armed later, a broadened path grants more
filesystem access than reviewed, a missing Developer ID channel can break the
shipping provider on the same OS policy, and a different arming owner severs the
evidence/authority chain. Acceptance criteria 2 and 3 require least privilege
and machine-checkable signing-channel rules.

## Independent reproduction

Starting from the attached r10 JSON, the reviewer changed both copies of each
coordinated field so row/register equality continued to hold:

1. `X1-C1.valuesIfArmed` and the `macos.provider` conditional row:
   `["/Library/Keychains/"]` -> `["/"]`.
2. `X1-C1.channelsIfArmed` and the same row:
   `["development", "developer-id"]` -> `["development"]`.
3. `X1-C1.armedBy`: `TASK-260715-1uxx3i` ->
   `TASK-260715-9yp8to`.

For all three mutations, `TASK-260715-ypo7yo_validate-matrix.py` reported
`PASS — every rule holds` and exited **0**, where a negative control must exit
**1**. The reviewer wrappers therefore exited **1**.

The first two artifacts were materialized under:

- `/tmp/ypo7yo-wide.SejpMa`
- `/tmp/ypo7yo-channel.kVvna6`

The owner-drift artifact was materialized under:

- `/tmp/ypo7yo-owner.N8BNBC`

## Required rework

1. Make R39 derive and require the exact `X1-C1` target, key, value set,
   signing-channel set, governing rule, and arming owner from K3 and the
   `macos.provider` channel contract, rather than accepting any internally
   consistent non-empty values.
2. Add negative mutations for coordinated row/register path widening, channel
   removal/addition, and arming-owner drift. Each must exit 1 and name R39.
3. Sweep the rest of the conditional pre-authorization fields for the same
   equality-only class, especially target/key drift, and either pin them or
   document why they are derived elsewhere.
4. Correct the rationale's r10 summary claim that R39 has “nine negative
   mutations”; the detailed section and executed harness show seventeen.
5. Refresh the board resource descriptions for the authoritative JSON,
   rationale, validator, and mutation harness. Their attached content is r10,
   while the current resource metadata still labels them r9.

No entitlement decision, current allowlist, C1 scope, identifier, profile row,
or legacy rule needs to change.

## Accepted surfaces and independent gates

The underlying r10 decision is otherwise sound. Apple’s current documentation
corroborates the channel-specific Network Extension values, the macOS
file-based/Data Protection Keychain distinction, default application-identifier
access groups, and registered `group.` App Group identifiers on macOS. The
macOS 15.0 base sandbox profile remains correctly modeled as unresolved rather
than inferred.

| Gate | Result |
| --- | --- |
| `validate-matrix.py` on unmodified r10 | 2654 checks, exit 0 |
| `mutate.py` supplied suite | 220/220 negative gates, exit 0 |
| `check-portal-consumer.py --repo .` | A1/P1/D1 pass, exit 0 |
| `preserve.py` r8 -> r9 | 122 assertions, exit 0 |
| `preserve-r10.py` r9 -> r10 | 201 assertions, exit 0 |
| `reviewer-gates.sh` | structural gates and D1 flip pass, exit 0 |
| `scripts/check-legacy-preservation.sh` | exit 0 |
| `task-board validate` | exit 0 |
| `swift test` | 335 tests in 29 suites, exit 0 |
| reviewer coordinated-drift controls | validators incorrectly exit 0; wrapper exit 1 |

The initial scoped board query used unknown field `acceptanceCriteria` and
exited 1; the corrected `ac` projection exited 0. No state changed during that
repair.
