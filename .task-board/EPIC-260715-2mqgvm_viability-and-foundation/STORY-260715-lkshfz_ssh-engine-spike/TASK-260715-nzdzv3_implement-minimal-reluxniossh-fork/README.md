# Implement the minimal ReluxNIOSSH fork

## Description
Create the smallest upstream-trackable SwiftNIO SSH patch set that makes child-channel receive-window policy configurable and exposes safe automatic client byte and time rekey while preserving server-initiated rekey behavior.

## Scope
In scope: fork from the pinned commit; configurable initial child windows and adjustment hooks; automatic byte and elapsed-time thresholds; safe request coalescing and key-exchange state; public or package API needed by the adapter; focused upstream-style tests; commit and patch inventory; notices; upstream tracking and rebase instructions. Out of scope: unrelated refactors, new SSH features, production lane scheduling, changing cryptographic algorithms, hiding failing tests, or retaining patches not required by the two blocked gates.

## Acceptance Criteria
1. The fork is based on the exact audited commit and each patch maps only to configurable channel windows, automatic client rekey, or tests and documentation for those behaviors. 2. Tests cover 32 KiB, 64 KiB, and larger capped windows, adjustment suppression, byte threshold, time threshold with injected clock, simultaneous threshold requests, active channels during rekey, and server-initiated rekey. 3. Default upstream behavior remains source-compatible unless the adapter opts into Relux policy. 4. A patch manifest, license review, upstream comparison, rebase procedure, conflict test command, and candidate upstreaming plan are attached. 5. No internal test-only symbol is called through reflection or other fragile access from product code.
