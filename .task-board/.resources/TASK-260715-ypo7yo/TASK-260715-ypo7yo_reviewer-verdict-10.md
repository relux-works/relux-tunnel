# TASK-260715-ypo7yo reviewer verdict 10

Verdict: **CHANGES REQUESTED**. Route: `analysis`.

This is recoverable contract and gate rework. It is not a Stop-The-Line external
blocker, and no portal mutation is authorized.

## Blocking finding

### F1 — `X1-C1.reviewedIn` accepts a revision that never reviewed the exception

Revision r11 correctly keeps conditional exception `X1-C1` unarmed and pins its
target, key, path, channels, governing rule, arming owner, and rendered scope.
However, R39 only requires `reviewedIn` to equal *any* revision present in the
contract or revision log.

That is weaker than the contract's own stated rule. The
`conditionalExceptionDerivation` says that pointing `reviewedIn` at an older
revision can imply a review that did not happen. `X1-C1` was introduced in r10
to close reviewer verdict 08; r2 predates the conditional exception entirely.

The reviewer changed only:

`exceptionEntitlementRule.conditionalExceptions[id=X1-C1].reviewedIn`

from `2026-07-28.r10` to `2026-07-28.r2`.

The current r11 validator then reported:

- `checks run: 2805`
- `PASS — every rule holds`
- exit **0**

The negative control is preserved at
`/tmp/ypo7yo-reviewed-in.iDOtWq`. A negative control must exit 1 and name
R39. As written, an accidental or coordinated edit can falsely attribute
pre-authorization to a revision that never reviewed this file exception,
breaking the evidence and authority chain behind future arming. This violates
the machine-checkability required by acceptance criterion 3 and prevents the
independent acceptance required by acceptance criterion 5.

## Required rework

1. Derive and require the exact revision that introduced/reviewed each
   conditional exception. For `X1-C1`, that revision is r10; deriving it from a
   pinned revision-log event or an equivalent immutable introduction record is
   acceptable.
2. Add a negative mutation that changes `X1-C1.reviewedIn` from r10 to a real
   older revision such as r2 or r3. It must exit 1 and name R39.
3. Update the derivation prose and independent reviewer gate so they no longer
   claim that `reviewedIn` is protected while accepting every issued revision.
4. Preserve all accepted r11 decisions and the exact C1 mutation scope; no
   entitlement, identifier, profile, dependency, or portal decision needs to
   change.

## Independent gate results

| Gate | Result | Exit |
| --- | --- | --- |
| `validate-matrix.py` | 2805 checks | 0 |
| `mutate.py` | 253/253 negative gates | 0 |
| `check-portal-consumer.py --repo .` | A1 27, P1 20, D1 41 | 0 |
| `preserve.py` r8 to r9 | 122 assertions | 0 |
| `preserve-r10.py` r9 to r10 | 201 assertions | 0 |
| `preserve-r11.py` r10 to r11 | 143 assertions | 0 |
| `reviewer-gates.sh` | supplied gates and four controls hold | 0 |
| `scripts/check-legacy-preservation.sh` | legacy identity preserved | 0 |
| `task-board validate` | no issues | 0 |
| `swift test` | 335 tests in 29 suites | 0 |
| reviewer `reviewedIn: r10 -> r2` control | validator incorrectly accepts | 0 |

The implementation otherwise matches the submitted r11 contract, the board
decomposition remains minimal and dependency-linked, the four production
identifiers and containment relationships are exact, the legacy
`works.relux.proxy` identity is preserved, and no portal mutation has begun.
