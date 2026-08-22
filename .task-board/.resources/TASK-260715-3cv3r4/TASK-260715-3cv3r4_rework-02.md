# Rework 02 — independent lifecycle resource accounting

Treat TASK-260715-3cv3r4_review-02-results.md as authoritative. Close only its remaining material finding without weakening the already accepted host-decision, Keychain guard, invalid-profile ordering, redaction, or safety behavior.

Required implementation and evidence:

1. Replace FixtureTransport self-owned/reset counters with one independently owned fixture lifecycle registry shared across every bounded repetition.
2. Register concrete connection and observer tokens at lifetime start; scope actual callback registrations with balanced teardown on success, every rejection class, thrown paths, and cancellation.
3. The registry—not FixtureTransport catch/reset compensation—must report baseline and retained-resource state. Do not make cleanup pass by assigning counters to zero.
4. Prove observable non-zero connection/observer/callback transitions while a deterministic gated operation is live, then restoration to the same shared baseline after success, all SSHHostKeyDecision rejection cases, and cancellation across repeated iterations. Prior-iteration leaks must remain observable.
5. Preserve no-real-Keychain/no-network/no-provider/no-VPN constraints and synthetic/redacted fixtures. Run focused repetitions, coverage, format, boundary, diff, prohibited-data scans, and task-board validation.
6. Correct the LOGBOOK claim, update the task outcome, attach distinct rework-02 evidence, and hand off to review.
