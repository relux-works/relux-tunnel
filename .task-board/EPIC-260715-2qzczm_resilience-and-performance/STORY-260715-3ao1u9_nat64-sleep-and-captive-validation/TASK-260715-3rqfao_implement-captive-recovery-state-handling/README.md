# Implement captive-network recovery state handling

## Description
Implement the M3 state and settings behavior for entering, negotiating, and leaving captive networks within Apple platform exceptions, preserving accurate compatible or fail-closed semantics while ordinary application traffic and DNS remain tunneled or fail explicitly.

## Scope
In scope: path and viability indications; reconnect handoff; compatible-mode recovery; fail-closed includeAllNetworks behavior and system captive exception; reasserting and finite reasons; SSH endpoint reconnect after access becomes usable; safe DNS gate; packet and flow admission; captive state timeouts and cancellation; route snapshots; privacy-safe metrics; controlled fixture tests. Out of scope: automating portal credentials, scraping portal pages, intercepting portal traffic, promising captive negotiation through the VPN, changing Apple exclusions, ordinary physical DNS, public network testing without authorization, or final UI copy.

## Acceptance Criteria
1. Entering a captive or non-viable path moves the provider to the documented reasserting or failed state and new ordinary flows cannot bypass the tunnel merely to improve portal success. 2. Compatible and fail-closed modes preserve their configured settings and documented Apple captive exception behavior without claiming absolute blocking beyond the platform. 3. When the access path becomes viable the current reconnect sequence re-establishes verified SSH, exact endpoint exclusion, safe DNS, settings, and capability in order with bounded retry. 4. Timeout, repeated captive changes, portal failure, path loss, stop, settings failure, stale callbacks, and host or auth failure have finite deterministic outcomes and no physical ordinary DNS fallback. 5. Controlled captive fixture and provider-fake tests cover entry, negotiation exception observation, success, failure, mode differences, simultaneous path changes, stop, redacted diagnostics, sentinels, and cleanup.
