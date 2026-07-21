# TASK-260715-30lv40 independent review verdict

Verdict: changes requested; route to analysis for contract rework. No external or human-only blocker exists.

## Evidence that passed

- The binding contract contains 11 concrete states, 32 declared legal transitions, and 64 finite reason rows. Full requires current authenticated SSH, packet/TCP, safe DNS, installed settings, and a current validated live relay; degraded preserves the same base with UDP closed and retired associations invalidated; failed, stopping, reasserting, stale, corrupt, and unknown projections advertise no usable bits.
- Production full/degraded remains gated by accepted M0 composition and production-authorized DNS policy. No final engine, MTU, lane/window, timing, or overlap value is selected.
- M2 relay-only reprobe and M3 path/host/route/lane/sleep/NAT64/captive reconnect ownership are separated; app/M4 is read-only for runtime truth.
- All 16 downstream precondition copies are byte-identical to the binding contract. Board validation and git diff whitespace checks pass.
- Both PlantUML sources pass PlantUML 1.2026.6 check-only and reproduce the attached PNG hashes. The ownership diagram is readable and source/render parity passes.
- Fresh executable validation passes: make core-test reports 306 tests in 27 suites; make relay-protocol-check reports 57 tests in 7 suites plus generation/schema checks and swift build; make relay-shell-test passes all Go packages and 11 release-script tests.
- The automatically attached zero-byte reviewer spawn log was deleted to preserve the explicit no-raw-spawn-log constraint.

## Required bounded rework

1. Retired relay callbacks are not generation-safe. Section 3 declares currentness only over runtimeGeneration, transportGeneration, and relayAttemptGeneration. T10, T22, T23, T24, and T25 retire or cancel attempt N without advancing relayAttemptGeneration; until N+1 starts, a delayed health/process/channel/timer callback from retired N still matches the declared tuple. Clearing activeRelayGeneration protects association identity but not non-association callbacks. Define an explicit current attempt/session registration predicate or retirement epoch/token, require every relay callback to carry and match it, and map post-retirement callbacks to stale_generation_ignored before transition/retry/snapshot work. Update the transition/state tables and downstream test handoff accordingly.

2. Exhausted/local-change retry has no legal recovery transition. T15 is degraded to degraded and only updates disposition; T20 sets relay_reprobe_exhausted; section 9 permits attempts only when the reason is already m2_relay_reprobe. Yet the catalog says exhaustion waits for an explicit local change or new trigger. Define the exact local event, guard, reason/reset behavior, generation action, retry owner, and transition back to waiting/running, or state that recovery requires an explicit stop/new start and use explicit_new_start consistently. No implementer should invent this edge.

3. Successful activation has no unambiguous finite published reason. After T04 succeeds, connectingActivation says relay result or current base failure, while none is catalogued only for fault-free full/idle and relay_bootstrap_pending no longer describes the completed bootstrap. Bind the success path explicitly to an existing stable token such as start_requested or add a finite activation token, then name it in the state and transition tables.

4. The lifecycle diagram collapses relayReprobeWaiting and relayReprobeRunning into one node and therefore hides the timer-consumption, failure-back-to-waiting, exhaustion, and cancellation distinctions that are central to exclusive retry ownership. Revise the lifecycle source/render to show both substates and reduce crossing labels while retaining one-purpose scope.

Re-review should rerun the 32-transition audit, source/render parity, 16 copy hashes, privacy scan, board validation, diff check, and the same core/relay test commands.