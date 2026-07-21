# Rework 02 — nonterminal UDP errors must not refresh association activity

Consume `TASK-260715-1loqwb_review-verdict-02.md`. Preserve the already-correct typed error classification and same-ID continuation; fix only the remaining idle-lifecycle mutation.

- Add or reuse a registry operation whose semantics are explicit: validate current generation, exact association ID/handle, and active state for a nonterminal control observation without refreshing activity, cancelling/replacing a timer, changing deadline/epoch, reserving queue credit, or allocating retry state. Do not weaken the identity/ABA checks by reading snapshots externally.
- Route only received `queueSaturated` and `datagramTooLarge` aggregate observation through that no-refresh operation. Keep their existing nonterminal metrics, same HEV channel, same association ID, zero close emission, and later bidirectional continuation.
- Do not alter normal datagram activity APIs: actual accepted outbound/inbound datagrams must continue to refresh the idle deadline exactly as already specified.
- Add deterministic `ManualUDPAdapterClock` tests for each nonterminal code. Capture exact registry `activityUpdates`, timer/deadline/arm evidence after admission, advance near the original deadline, inject the error, prove every activity/timer value remains unchanged, then prove expiry occurs at the original deadline and cleanup/close is exactly once. Keep or extend the existing same-ID traffic and independent close coverage without sleeps.
- Cover stale generation, unknown association, and already-closing observation results if the new registry API creates distinct branches; they must remain finite, privacy-safe, and non-mutating.
- Re-run focused 5×, focused TSan, full Swift, relay protocol check, strict format/diff, core boundaries, privacy/public-proxy scans, build and board validation. Update task-scoped outcome evidence and logbook, then hand off to `to-review`.

Do not change the wire schema, error taxonomy, final limits, SSH pump, DNS behavior, or public proxy boundary.
