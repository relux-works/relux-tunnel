# TASK-260715-1juybj rework 01 review verdict

Verdict: changes requested -> analysis. No external or human-only blocker exists.

## Blocking finding

The corrected ownership-sequence diagram is visually legible but semantically contradicts the source-backed admission contract. `diagrams/TASK-260715-1juybj_ownership-sequence.puml:14-20` places `pending limit` in an authentication-result branch after the greeting and RFC 1929 request and permits `[01 01] when safe`. Current production checks pending capacity immediately after `accept` and closes a rejected descriptor before starting authentication (`HEVSOCKSBoundary.swift:284-299`). The contract likewise says a socket rejected before acquiring a pending-authentication slot closes immediately without joining negotiation (`TASK-260715-1juybj_contract.md:185-188`). Section 9 calls the task-scoped diagrams normative, so this is not safe to leave as an illustrative shortcut.

Required rework: split pending-capacity/stopped rejection into a branch immediately after TCP accept that closes without method negotiation or an RFC 1929 reply; keep stale/wrong capability and monotonic-deadline expiry in the authentication branch. Re-render and opaque-background inspect the ownership sequence, update its outcome copy, hashes, validation and rework evidence, and rerun PlantUML syntax/render, board/resource-copy verification, and `git diff --check`. No code change is requested.

## Passing evidence retained

The current SO_RCVTIMEO behavior is now stated accurately as restartable per-receive inactivity with no send deadline. The absolute monotonic accept-to-authentication deadline remains an explicit M1 implementation requirement, and TASK-260715-b6uruh now requires deterministic slow-trickle, wrong-credential, both-reply-stall, cancellation, stale-generation, slot-recovery, descriptor-cleanup, and iOS/macOS validation rows. The byte-level SOCKS contract, remote destination and sanitized originator, exactly-one channel/no migration, bounded pumps, EOF/half-close/reset/cancellation/cleanup, M0 accounting, privacy-safe aggregate metrics, and M3 assignment seam remain review-passing. Both opaque renders are legible and unclipped.

Independent reviewer validation on 2026-07-21: `swift test` passed 276 tests in 25 suites; both PlantUML sources passed `-checkonly`; `task-board validate` passed; authored/resource diagram copies and recorded SHA-256 hashes matched; `git diff --check` passed.