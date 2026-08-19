# Eliminate intermittent harness signal-cancellation cleanup timeout

## Description
Make the ReluxTunnelHarness signal-cancellation test and its production cleanup path deterministic under repeated and loaded Swift Testing execution. Fix the synchronization or ownership race rather than extending arbitrary sleeps or weakening cleanup assertions.

## Scope
In scope: harness signal delivery/observation, process-exit coordination, cleanup ownership, timeout diagnostics, focused stress tests, repeated clean full-suite and coverage evidence. Out of scope: changing product VPN behavior, weakening signal-exit or zero-resource assertions, global timeout inflation, signing, installation, VPN activation, routes, or DNS mutation.

## Acceptance Criteria
1. A deterministic stress harness reproduces or directly exercises the pre-fix race window and identifies the ownership/synchronization cause. 2. The fix uses explicit event or process-state synchronization; it does not hide the race with longer arbitrary sleeps, retries, or weaker assertions. 3. Signal exit semantics remain correct and every temporary directory, socket, task, descriptor, and handler is released exactly once on success, timeout, and cancellation. 4. At least 50 focused repetitions under load, three clean full swift test runs, one coverage run, strict lint, and boundary checks pass without an unexpected issue. 5. Evidence is privacy-safe and performs no signing, installation, application/provider launch, VPN preference mutation, VPN activation, route change, or DNS change.
