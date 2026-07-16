# Verify published channels and open the rollback watch

## Description
After approved publication or review acceptance, verify remote macOS and iOS channel state, installability, metadata and policy visibility, support readiness, monitoring boundaries, and the time-boxed rollback watch without introducing traffic telemetry.

## Scope
In scope: authenticated GitHub stable and versioned assets, checksums and links, App Store or TestFlight build and storefront state, public listing, screenshots, policy and support URLs, clean install smoke, version and relay identity, review-fixture retirement timing, support contact and known issues, CI and channel audit logs, crash or diagnostic handling only as approved, rollback owner and window, incident triggers, and closure evidence. Out of scope: traffic analytics, destination monitoring, changing installed apps remotely, expanding storefronts, collecting reviewer or user traffic, declaring success from dashboard state alone, and bypassing rollback criteria.

## Acceptance Criteria
1. Operators independently fetch or view every approved channel and verify artifact or build identity, versions, storefronts, checksums, metadata, screenshots, policy and support URLs, and availability against the go decision. 2. A clean supported device installs or updates through each intended channel and completes a bounded privacy-safe launch and VPN lifecycle smoke. 3. Support, incident, credential, review-fixture, and rollback owners acknowledge readiness and monitoring collects no traffic, destination, DNS, key, or passphrase data. 4. Any wrong asset, stale stable link, missing storefront, broken URL, metadata drift, install failure, review credential exposure, or severe incident triggers the documented hold or rollback path. 5. The watch closes only after the approved interval with channel evidence, issues and dispositions, credential or fixture cleanup, and an explicit residual-risk and rollback-window handoff.
