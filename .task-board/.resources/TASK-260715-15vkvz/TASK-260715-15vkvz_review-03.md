# TASK-260715-15vkvz review 03 — changes requested

## Finding

1. P1 — Both platform terminal-status observers have a lost-notification race. IOSVPNStatusObservation reads connection.status at IOSVPNManagerPreferences.swift:146, then registers NEVPNStatusDidChange at line 152; MacOSVPNStatusObservation has the same read/register gap at MacOSVPNManagerPreferences.swift:147-153. If stopVPNTunnel transitions the connection to disconnected or invalid after the read but before registration, the terminal notification is missed and no subsequent status read occurs. disableOwnedManager and removeOwnedManager then wait until the 15-second deadline and return stopTimedOut even though the session is already terminal. This violates the accepted deterministic callback-order and stop-observation contract. Install the observer before the authoritative status check, or perform a race-safe post-registration recheck through an injectable seam, and add deterministic tests for terminal-before-registration, terminal-during-registration, notification-first, and cancellation/late-notification retirement on both adapters.

## Closed prior findings

Rework 02 closes review 02: the FIFO operation gate prevents repository reentrancy across suspended preference callbacks, concurrent zero-manager ensure creates one canonical manager, and iOS/macOS NSNumber decoding preserves Bool/fractional type confusion plus signed/unsigned future versions without narrowing or mutation. Review 01 future-version, transition, stale-replacement, and distinct reload-verification findings remain closed.

## Independent validation

- swift test --filter OwnedVPNManagerRepositoryTests: PASS, 27 tests.
- swift test --sanitize=thread --filter OwnedVPNManagerRepositoryTests: PASS, 27 tests.
- make validate-core: PASS, 245 tests in 24 suites plus build.
- swift format lint --strict --recursive Sources Tests Package.swift: PASS.
- tracked and untracked diff whitespace checks: PASS.
- task-board validate: PASS.
- generic iOS Simulator ReluxTunnelIOSAdapter build: BUILD SUCCEEDED.
- generic macOS ReluxTunnelMacOSAdapter build: BUILD SUCCEEDED.

Verdict: changes requested; route to to-dev for race-safe platform terminal observation and deterministic callback-order tests, followed by a fresh reviewer cycle.