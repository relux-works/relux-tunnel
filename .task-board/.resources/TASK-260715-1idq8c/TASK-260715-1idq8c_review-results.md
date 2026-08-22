# TASK-260715-1idq8c reviewer outcome

## Verdict

Changes requested. Route to `to-dev`.

## Blocking finding

`scripts/run-apple-ui-test-smoke.sh:68-72` can ignore a failed xcresult screenshot extraction and still return the prior successful Xcode status. `run_ui_test` is invoked as the condition of an `if` at lines 93-101; under POSIX shell semantics, `set -e` does not stop the function when the extractor fails in that conditional context. The subsequent `return "$row_status"` returns `0`, so `ios_status=0` and `aggregate_build_host_exit=0` can be recorded even when the required step screenshots and `screenshots.json` were not produced.

Independent reproduction: a function with the same control-flow shape ran a simulated extractor returning nonzero, then printed `OBSERVED: caller records ios_status=0 despite extractor failure` and exited `0`. Evidence: `.temp/TASK-260715-1idq8c-review/smoke-extractor-fail-open-repro-01.log`.

This violates revised AC4 and the task DoD because the aggregate build-host gate can report success without screenshot-extraction evidence. Fix by explicitly capturing/propagating extraction failure, validating the required extracted artifacts before success, and adding a negative regression test that proves the aggregate gate is nonzero when extraction fails.

## Independent verification

- `make apple-ui-test-contract`: exit `0`; static safety check, extractor unit test, all 18 typed fixture round-trips, and snapshot-diff artifact test passed. Log: `.temp/TASK-260715-1idq8c-review/apple-ui-test-contract-01.log`.
- `make apple-ui-test-smoke`: exit `0`; review run `.temp/TASK-260715-1idq8c/apple-ui-test/run.0T3bU8`. Summary: native macOS build-for-testing `0`, native macOS runtime explicitly deferred to `TASK-260822-3q4grm`, iOS Simulator Xcode `0`, controlled snapshot mismatch `1`, aggregate `0`.
- Native macOS `.xctestrun` inventory exists and names only the fixture host/UI-test runner. No native macOS runtime was launched.
- Safety scan of fixture host, shared package, UI-test sources, and target graph found no `NetworkExtension`, VPN preference, provider, route/DNS/interface/pf, or network-client path.
- Both extracted iOS PNGs were inspected at original `1206x2622` resolution: portrait orientation, centered unclipped layout, expected diagnostic/safety/action/state content, and no black/empty/frozen rendering.
- `make workspace-validate`: exit `0`; `swift build`: exit `0`; `git diff --check`: exit `0`; shell/Python syntax checks: exit `0`.
- Corrected `swift format lint --recursive --strict ...`: exit `0`. An earlier reviewer invocation without `--recursive` exited `64`; this was reviewer command misuse, not a project lint failure.
- Full `swift test`: exit `0`; 455 tests in 40 suites passed with 25 declared known unavailable-adapter issues. The producer's prior unrelated `clientAndServerRekey` close-state failure did not reproduce and has no causal overlap with this diff, so it remains an intermittent SSH timing anomaly.
- `task-board handoff TASK-260715-1idq8c --role reviewer`: exit `1` with `role "reviewer" has no end_status and cannot use handoff`. This is consistent with the verdict-driven reviewer role; the explicit `to-dev` status branch is the handoff mechanism.

## AC assessment and residual risks

- AC1, AC2, AC3, and AC5: accepted by source inspection and passing focused/runtime evidence.
- AC4: not accepted until extraction failure propagates to the aggregate result and a negative regression test covers it.
- Signed native macOS fixture-host/XCUITest runtime remains correctly owned by `TASK-260822-3q4grm` on the dedicated test Mac. Physical-device evidence remains separate. No signing, provider launch/install, VPN preference mutation, or system-network mutation was performed during review.
