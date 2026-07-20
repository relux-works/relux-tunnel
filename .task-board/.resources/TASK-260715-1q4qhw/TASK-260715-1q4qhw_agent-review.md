# TASK-260715-1q4qhw — independent agent-review verdict

Reviewer: independent `/root/vpn_contract_reviewer` agent  
Verdict: **ACCEPTED after one correction pass**  
Review scope: five task AC, Apple public API semantics, accepted runtime models,
identifier/entitlement provenance, macOS-first scope, diagrams, and downstream
task readiness.

## First-pass changes requested

1. Remove an exact entitlement serialization that was not yet accepted; retain
   symbolic bindings to `TASK-260715-ypo7yo` and macOS packaging owner
   `TASK-260715-1tzaed`.
2. Prevent explicit duplicate repair from removing/downgrading any future or
   unprovable owned manager/reference schema.
3. Add exact terminal start/disconnect mappings for all public
   `NEVPNConnectionError` values, provider-domain values, nil errors, and
   last-error timeout/cancellation.
4. Treat a nil `loadAllFromPreferences` managers collection as a named
   zero-write failure rather than an empty result.
5. Separate owned-disabled from observed `.invalid` and add missing invalid,
   disconnect, and system-failure transitions to the authority diagram.

## Accepted re-review

The reviewer independently confirmed all five corrections:

- no exact entitlement value remains; production bindings fail closed;
- duplicate repair pre-decodes versions and preserves future/unprovable owned
  configurations;
- all 19 public connection errors, provider codes 1001–1009/unknown, nil,
  timeout, cancellation, pending-start, and established-session outcomes are
  explicit;
- nullable load results cannot enter mutation logic; and
- the authority diagram distinguishes disabled/disconnected/invalid, covers
  terminal transitions, and clears capability outside connected state.

The reviewer found no new contract/source/task contradiction. The exact
three-part owned predicate, unrelated-manager zero-mutation proof, save/reload
and stale flows, system/provider authority split, once-only deadlines,
host-process independence, public API boundary, accepted Runtime model usage,
and macOS-first/iOS-deferred scope satisfy the task AC. Refined repository,
session, and router tasks carry the corrected requirements and dependencies.

Independent checks reported by the reviewer:

```text
java -jar .temp/tools/plantuml.jar -checkonly \
  .temp/TASK-260715-1q4qhw_manager-provider-sequence.puml \
  .temp/TASK-260715-1q4qhw_authority-state.puml
task-board validate
```

Both passed. The reviewer made no file or board mutation.
