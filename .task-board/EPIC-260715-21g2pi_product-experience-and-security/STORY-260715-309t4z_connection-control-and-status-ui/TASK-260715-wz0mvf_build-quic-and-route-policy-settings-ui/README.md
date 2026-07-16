# Build QUIC and route-policy settings UI

## Description
Build iOS and macOS settings for Auto, Allow QUIC, Block UDP/443 and compatible versus platform-supported fail-closed routing. Explain capability and system exclusions accurately and publish changes as versioned profile configuration.

## Scope
In scope: enum controls, selected/default values, per-policy explanations, degraded interaction, compatible and fail-closed disclosures, platform availability, confirmation where traffic behavior materially changes, active-session edit behavior, versioned persistence, rollback/error state, accessibility, localization, identifiers, and tests. Out of scope: implementing UDP classification, Auto evaluator, network settings, private API, universal fail-closed claims beyond Apple guarantees, and arbitrary per-app routing.

## Acceptance Criteria
1. Both platforms expose exactly the M3-approved policy values and defaults, disable unsupported combinations with a specific explanation, and never advertise fail-closed coverage beyond platform-guaranteed exclusions. 2. Auto explains possible fast UDP/443 failure and HTTP/2 fallback, Allow explains dependence on UDP capability, and Block explains deterministic UDP/443 rejection without describing it as traffic inspection. 3. Changes write a new profile generation, show selected versus active value, and follow the active-session safeguard contract for apply-now, reconnect, or later behavior. 4. Persistence, validation, publication, failure rollback, relaunch, and stale edit outcomes are deterministic and privacy-safe. 5. Unit/snapshot/UI tests cover every value, capability state, platform branch, long copy, VoiceOver/keyboard, confirmation, cancel, error, and relaunch.
