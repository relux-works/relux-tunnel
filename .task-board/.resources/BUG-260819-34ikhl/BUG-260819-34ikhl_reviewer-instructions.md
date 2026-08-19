# Independent review instructions

Review only `BUG-260819-34ikhl` and its delta. Verify the exact root cause and prove the fix removes scheduler-dependent polling without weakening the original signal-exit and cleanup contract.

Inspect the actor/continuation state machine for missed wakeups, double resume, waiter leaks, indefinite hangs if startup fails, and exactly-once managed-task cancellation. Confirm actor isolation makes the check-and-register operation atomic and that all relevant completion/cancellation paths release ownership.

Independently run focused stress under load and enough clean/full evidence to validate the producer's claims. Confirm no arbitrary sleep extension, blind retry, relaxed cleanup assertion, or production behavior change was introduced. Verify formatting, boundary checks, and privacy/build-only safety.

Never sign, install, launch, save, start, or stop a VPN; never mutate NetworkExtension preferences, routes, or DNS on this development Mac.

If accepted, record a verdict and leave commit-confirmed terminal movement to the orchestrator. Otherwise return the bug to `to-dev` with exact reproducible findings.
