# Implement connected-profile switching and configuration safeguards

## Description
Implement explicit behavior for switching profiles, deleting the active profile, and editing host, key, trust, QUIC, or route settings while a VPN session is connecting, connected, reasserting, or disconnecting. Never mutate a running generation silently.

## Scope
In scope: selected versus active profile generations, harmless metadata edits, connection-affecting edit classification, disconnect-and-switch confirmation, stop observation, fresh start, cancellation, rollback, delete restrictions, pending selection, stale events, app relaunch, UI model integration, and typed errors. Out of scope: seamless live flow migration, multi-hop profiles, automatic background switching, reconnect engine implementation, and storage implementation.

## Acceptance Criteria
1. A running provider remains bound to its immutable active profile generation; connection-affecting edits or deletion cannot alter it in place. 2. Switch/reconnect requires explicit confirmation, observes bounded disconnect completion, starts only the newly selected durable generation, and rolls back selection or reports a recoverable failure on any step error. 3. Duplicate requests, app background/termination, system stop, reasserting, concurrent profile deletion/edit, stale callbacks, and cancellation produce one deterministic active/selected outcome. 4. Non-connection metadata edits follow the contract without implying a runtime change and the UI clearly distinguishes active versus selected values. 5. Tests cover every session state, edit class, failure injection point, relaunch, rollback, and resource cleanup without traffic fallback or hidden migration.
