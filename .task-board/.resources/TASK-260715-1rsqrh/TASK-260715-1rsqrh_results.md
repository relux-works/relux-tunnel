# TASK-260715-1rsqrh — state mapping and verification evidence

## Implemented authority model

- Every command asks `OwnedVPNManagerRepository` for a freshly loaded, exact-owned current manager and its retained `NETunnelProviderSession`.
- `NETunnelProviderSession.status` is the only system-session authority. Host memory is limited to cancelling/retiring in-flight work and rejecting stale callbacks; it never owns forwarding state.
- Provider lifecycle and capability snapshots are accepted only while the exact system session is connected, after v1 protocol negotiation, request correlation, schema/size validation, and a matching generation/sequence position strictly newer than the last accepted position.
- Every non-connected system status clears provider facts. Missing, nil, late, corrupt, unsupported, future-schema, wrong-request, mismatched, stale, and out-of-order provider responses leave a connected session capability-unknown.
- Controller retirement releases observers/tasks without stopping the system tunnel. A newly created controller recovers from a fresh system read plus fresh provider snapshots.

## Command and projection mapping

| Authoritative system status | Start preflight | Stop behavior | Provider capability projection |
| --- | --- | --- | --- |
| `invalid` | Reload once; reject as `sessionInvalid` if still invalid | Already stopped; no stop call | Cleared |
| `disconnected` | Send exactly one bounded v1 start request and observe up to 60 seconds | Already stopped; no stop call | Cleared |
| `connecting` | Return `alreadyStarting`; no start call | Stop once and observe terminal status up to 15 seconds | Cleared |
| `connected` | Return `alreadyConnected`; no start call | Stop once and observe terminal status up to 15 seconds | Fresh provider facts only |
| `reasserting` | Return `systemReasserting`; no start call | Stop once and observe terminal status up to 15 seconds | Cleared |
| `disconnecting` | Reject as `sessionBusyDisconnecting`; no start call | Join terminal observation; no duplicate stop call | Cleared |

An accepted start that is cancelled or reaches the 60-second deadline claims exactly one system stop and never reports connected. Concurrent stop callers join one shared 15-second terminal observation. A stop timeout reports `stopTimedOut` and does not claim cleanup.

Disconnect-reason mapping covers every public `NEVPNConnectionErrorDomain` code 1–19, provider-domain codes 1001–1009, unknown provider/system codes, nil error after start failure versus an established disconnect, and timeout/cancellation unavailability. The reason supplements but never overrides system status.

## Code and tests

- Shared controller: `Sources/ReluxTunnelCore/VPNSessionController.swift`
- Fresh repository handoff: `Sources/ReluxTunnelCore/VPNManagerRepository.swift`
- Thin public NetworkExtension adapters: `Sources/ReluxTunnelIOSAdapter/IOSVPNManagerPreferences.swift`, `Sources/ReluxTunnelMacOSAdapter/MacOSVPNManagerPreferences.swift`
- Deterministic controller matrix: `Tests/ReluxTunnelCoreTests/VPNSessionControllerTests.swift`
- Repository handoff coverage: `Tests/ReluxTunnelCoreTests/OwnedVPNManagerRepositoryTests.swift`

## Verification

| Check | Result | Evidence |
| --- | --- | --- |
| Focused normal controller/repository tests | 57 tests, 2 suites passed | `focused-normal-03.log` |
| Focused controller TSan tests | 23 tests, 1 suite passed; zero race reports | `focused-tsan-03.log` |
| Full core validation | 275 tests, 25 suites passed; core build passed | `validate-core-02.log` |
| Strict Swift format lint | Passed | `swift-format-01.log` |
| Tracked diff whitespace check | Passed | `diff-check-01.log` |
| iOS simulator adapter build | `BUILD SUCCEEDED` | `ios-build-01.log` |
| macOS universal adapter build | `BUILD SUCCEEDED` | `macos-build-01.log` |
| Board validation | Passed | `board-validate-01.log` |

The focused suites explicitly exercise start/stop races, stale and out-of-order snapshots, app recreation, protocol incompatibility and future schemas, every system status, nil/late callbacks, deadlines/cancellation, observer release, generation retirement, and recovery from current system plus provider authorities.
