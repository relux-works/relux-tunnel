# TASK-260715-1q4qhw — residual risk and completeness evidence

## Closed in this contract

- Exact, schema-independent ownership predicate and negative proof rows.
- Separate ensure, explicit enable, start, message, stop, disable, duplicate
  repair, and remove operations.
- Save/reload, stale-object one-retry rule, late callback retirement, and stable
  error mappings.
- System-session versus provider-capability authority.
- Both-platform once-only completion ownership, 60 s start, 10 s provider stop,
  15 s host preference/stop observation, 3 s message, and 2 s sleep deadlines.
- Host suspension/termination independence and public-API-only boundary.

## Residual risks with owners

| Risk/gap | Current effect | Owner / gate | Blocking this draft? |
|---|---|---|---|
| Exact four production bundle IDs, App Group, Keychain group, and development/release entitlement values and placement are not accepted | production identity injection must fail closed; deterministic implementation/tests can proceed | `TASK-260715-ypo7yo`, macOS release contract `TASK-260715-1tzaed`, then provisioning task `TASK-260715-3jloqy` | No |
| Enabling one enterprise VPN can cause the OS to disable another enterprise VPN | enable is explicit user intent and outcome must disclose system effect | host repository/controller; final wording in later UX task | No |
| NetworkExtension exposes no stable public “permission granted” preflight or universal permission-denied code | success only after save/reload; other authorization errors retain redacted domain/code | `TASK-260715-15vkvz` tests and physical macOS gate | No |
| Apple preference and provider completion calls are not cancellable | local operation tokens retire late callbacks; next action reloads/reconciles | repository/provider implementations and lifecycle tests | No |
| A hard provider cleanup deadline cannot prove an uncooperative third-party/native resource exited | force-close controllable handles, complete OS callback, record deadline failure; native ownership gates remain upstream | `TASK-260715-1bp6eu`, accepted M0 composition manifest | No |
| Reconnect/path change and fail-closed route policy are intentionally absent | reasserting never synthesizes recovery; fatal health cancels; flags remain compatible/false | M3/later routing and reconnect tasks | No |
| iOS adapter parity exists in the contract but macOS-first v1 does not authorize iOS product/UI/release execution | keep iOS adapter task deferred; do not place it on macOS-first launch path | story/orchestrator planning | No |
| Human governance ratification is decoupled | agent-reviewed contract can feed implementation before human checkpoint | `TASK-260717-1dsqnj` | No |

## Downstream task completeness

Existing atomic tasks cover repository (`TASK-260715-15vkvz`), session/status
(`TASK-260715-1rsqrh`), message/cleanup (`TASK-260715-1bp6eu`), macOS provider
(`TASK-260715-3dv8ea`), deferred iOS parity provider (`TASK-260715-2hiabd`), and
cross-cutting tests (`TASK-260715-3lab1f`). Their dependency edges already make
this contract a prerequisite. No new research task is required: every unresolved
fact has an existing named owner and the attached instruction explicitly permits
implementation against accepted symbolic bindings.

The manual ratification task `TASK-260717-1dsqnj` required refinement because
its scope and acceptance criteria were placeholders; this architecture handoff
updates it without placing ratification on the implementation critical path.
