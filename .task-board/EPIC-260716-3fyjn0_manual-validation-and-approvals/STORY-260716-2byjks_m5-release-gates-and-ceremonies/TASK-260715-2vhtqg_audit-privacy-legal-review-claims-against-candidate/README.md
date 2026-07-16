# Audit privacy, legal, metadata, and App Review claims against the candidate

## Description
Independently compare the exact signed iOS and macOS candidates and observed behavior with public policy, in-app disclosure, App Privacy labels, export answers, regional settings, metadata, screenshots, review notes, support documentation, and test instructions.

## Scope
In scope: static strings and resources, runtime first-enable disclosure, network and dependency scans, diagnostic and export artifacts, candidate entitlements, relay and routing behavior, full and degraded states, system exclusions, telemetry absence, retention and deletion controls, policy, labels, export and legal declarations, storefronts, listing claims, screenshots, support URLs, fixture instructions, approvals, versions, and discrepancy register. Out of scope: legal advice by auditor, implementing corrections, accepting unsupported claims because they are favorable, production traffic, and reviewing a different build.

## Acceptance Criteria
1. Every external and in-app claim maps to exact candidate behavior, configuration, dependency inventory, test evidence, and accountable approval with no orphan or contradictory statement. 2. The audit specifically tests user-owned SSH exit, observer visibility, Relux Works data-path role, zero baseline telemetry, diagnostics, support export, retention and deletion, system exclusions, full and degraded capability, and regional availability. 3. App Privacy labels, privacy manifests, export answers, entitlements, policy, metadata, screenshots, review notes, and instructions agree on versions and facts. 4. Runtime network sentinels and artifact scans find no unreported analytics, traffic telemetry, production credential, destination or DNS logging, or support upload. 5. Any unsupported, stale, missing, overbroad, region-conflicting, or inaccessible claim blocks go or no-go and the verdict lists exact correction owner and invalidated downstream evidence.
