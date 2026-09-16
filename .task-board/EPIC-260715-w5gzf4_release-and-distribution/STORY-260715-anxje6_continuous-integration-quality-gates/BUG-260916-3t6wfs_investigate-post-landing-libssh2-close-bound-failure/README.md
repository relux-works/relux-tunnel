# BUG-260916-3t6wfs: investigate-post-landing-libssh2-close-bound-failure

## Description
Post-landing hosted CI run 35103482648 on db89c1a555fd4cf57a1cba7fe7bf998f6951b1f2 failed one Swift Testing assertion: LibSSH2BridgeTests.swift:380 transport close is bounded when socket teardown ignores cancellation observed 1.17695875 seconds against less than 1 second. Exact-head prelanding PR run 35098918403 passed 7/7. Cause is unconfirmed; preserve both outcomes and investigate production cancellation bound versus test scheduling before choosing a fix.

## Scope
Inspect and reproduce the bounded transport-close failure with isolated credential-free tests; make the smallest evidence-backed production or test synchronization correction. Do not weaken required checks, blindly increase the timing threshold, fake CI status, change VPN settings, or mix with SSH bootstrap work. One Muse max worker after current bootstrap producer reaches a safe handoff; independent Astra low review and real hosted CI are required.

## Acceptance Criteria
1. Persist exact hosted failure and green comparator provenance. 2. Establish the root cause with a test that distinguishes bounded close semantics from scheduling latency, retaining cancellation-ignoring socket coverage. 3. Run relevant tests and existing required gates without skipping failures. 4. Deliver an independently reviewed signed PR through exact-head green-check landing.
