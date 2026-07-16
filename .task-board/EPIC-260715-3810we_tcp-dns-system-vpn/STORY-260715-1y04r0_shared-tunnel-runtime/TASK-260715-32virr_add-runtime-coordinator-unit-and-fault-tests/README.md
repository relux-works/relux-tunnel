# Add deterministic runtime coordinator unit and fault-injection tests

## Description
Build the shared test suite for the runtime coordinator using controllable dependencies, clocks, callbacks, and resource counters. Exercise legal and illegal transitions, every startup failure boundary, concurrent control events, stale generations, and cleanup without relying on wall-clock sleeps.

## Scope
In scope: start success, validation failure, SSH failure, packet or DNS preparation failure, settings failure, packet-read failure, stop during each step, duplicate start and stop, late callbacks, dependency health loss, error mapping, ordering assertions, and resource baselines. Out of scope: real Network Extension APIs, real SSH servers, HEV performance, physical-device tests, UDP, reconnect policy, and UI tests.

## Acceptance Criteria
1. A table-driven suite injects failure before and after every acquired resource and asserts exact rollback order and single completion. 2. Concurrent start or stop and late-generation callbacks never create two active runtimes or revive a stopped generation. 3. Usable capability is emitted only after the required ordering conditions and is revoked on mandatory failure. 4. At least one hundred deterministic lifecycle iterations show no retained task, timer, socket, channel, or dependency count growth in the fixture. 5. Tests use fake clocks or explicit continuations and pass under race-sensitive repeated execution without sleep-based correctness.
