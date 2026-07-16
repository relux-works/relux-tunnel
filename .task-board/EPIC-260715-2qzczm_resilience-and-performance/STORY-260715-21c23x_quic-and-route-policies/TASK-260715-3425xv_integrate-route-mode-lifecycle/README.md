# Integrate route-mode startup, change, reconnect, rollback, and stop

## Description
Integrate the selected route mode into provider startup and reconnect settings transactions, including live profile changes, exact endpoint replacement, atomic capability publication, rollback on failure, stop cleanup, and route or DNS safety.

## Scope
In scope: validated profile route mode; compatible and fail-closed builder; authenticated actual endpoint; M1 startup and M3 reconnect transaction; includeAllNetworks application; settings generation; live change policy and reconnect trigger; packet-read and traffic gates; apply timeout and failure; rollback or explicit failure; provider snapshot; diagnostics; both providers. Out of scope: building settings internals, selecting endpoint, UI controls, platform entitlement decisions, physical captive handling, per-app rules, broad exclusions, or fallback DNS.

## Acceptance Criteria
1. Startup applies the validated selected mode only after authenticated endpoint and safe-DNS readiness and publishes usable capability only after current settings and packet reads succeed. 2. Route-mode or endpoint change creates one generation-safe transaction and pending traffic cannot use a mixed old and new route or DNS configuration. 3. Apply failure, timeout, cancellation, unsupported fail-closed mode, reconnect failure, and stop produce the contractually safe rollback or non-usable failure with no false-connected snapshot. 4. Exact endpoint exclusion, include-all setting, dual-stack routes, tunnel DNS, and mode snapshot remain mutually consistent across replacement and no recursive SSH route or broad bypass is introduced. 5. Provider-fake and composed fault tests cover both platforms and modes, startup, live change, reconnect, same and changed endpoint, failure at every boundary, stale callback, stop, sentinels, and cleanup.
