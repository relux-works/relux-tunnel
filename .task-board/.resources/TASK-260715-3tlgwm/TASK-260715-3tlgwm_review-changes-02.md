# TASK-260715-3tlgwm reviewer verdict — changes requested 02

Date: 2026-07-21
Role: reviewer
Verdict: CHANGES REQUESTED
Route: to-dev

## Rework 01 verification

The reported startup-completion health handoff race is closed. After the startup child returns, start now revalidates caller cancellation, environment cancellation, actor state, and termination before clearing startupTask with no intervening suspension. The two new deterministic tests force current-generation DNS health loss and caller cancellation into that handoff; neither issues a later stop, and both prove exactly-once reverse cleanup plus internal and external resource baselines.

## Remaining acceptance blocker

A stop that serializes before start is discarded, so the stopped generation can later start and the stop does not return retained configuration references to baseline.

Code evidence:

- The coordinator is initialized in disconnected while retaining context.configuration.profileReference (TunnelRuntimeCoordinator.swift lines 321 and 330-340).
- stop returns immediately for disconnected without setting termination, consuming the generation, clearing the configuration reference, or starting cleanup (lines 389-395).
- hasStarted therefore remains false, and a later start passes its only consumption guard and transitions the same generation into startup (lines 358-369).
- The recorded baseline requires retainsConfigurationReference=false (TunnelRuntimeCoordinatorTests.swift lines 932-943), but no test asserts it after a pre-start stop.
- The existing concurrent start/stop test forces start to reach a startup gate before stop is issued (lines 87-116), so it covers only the start-wins ordering.

Failing schedule:

1. A coordinator is created with its configuration reference retained and state disconnected.
2. stop enters the actor before start.
3. stop returns as a no-op; the configuration reference remains retained and the generation remains startable.
4. start enters later, passes hasStarted=false, and can apply settings and publish usable capability after the stop already completed.

This violates AC1 because the serialized stop event does not prevent later mutation/revival of the same generation, and AC5 because stop completes with a retained configuration reference instead of the recorded baseline. It also leaves the provider integration vulnerable to a stop/start scheduling inversion around the cross-actor runtime call.

## Required rework

- Make a stop that wins in the initial disconnected state terminally consume or cancel that generation, release its retained configuration reference, and prevent any later start from reviving it.
- Add deterministic coverage for stop-before-start and a stop-wins concurrent start/stop ordering. Assert start cannot proceed, no settings or usable capability is published, repeated stop remains idempotent, cleanup completes once, and resourceFootprint plus the external ledger equal baseline.
- Preserve the accepted startup-completion handoff checks and their two regression tests.

## Independent validation

The current suite is green but omits the failing ordering:

- swift test --filter TunnelRuntimeCoordinatorTests: 13 tests passed.
- swift test --sanitize=thread --filter TunnelRuntimeCoordinatorTests: 13 tests passed with no Thread Sanitizer report.
- make validate-core: boundary and native checks passed; 205 tests in 23 suites passed; post-test swift build passed.
- swift-format lint --strict --recursive Sources Tests Package.swift: passed with no diagnostics.
- git diff --check plus untracked-file whitespace checks: passed.
- task-board validate: passed.

This is ordinary implementation rework, not a stop-the-line boundary.