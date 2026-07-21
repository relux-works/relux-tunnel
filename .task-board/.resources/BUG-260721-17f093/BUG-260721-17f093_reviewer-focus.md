# Independent review: DNS evidence validator assertion fix

Review `BUG-260721-17f093` independently against its AC and `TASK-260721-3miqh4_re-review-02-verdict.md`.

- Inspect all timing vectors and prove they mutate the declared field and exercise the real validator with the expected error; reject any self-comparison or dead vector.
- Mutate/remove every authority-critical policy field and verify canonical policy validation fails closed, including exact blocker identities and physical-gate declaration.
- Verify exact reliability assertions for all 14 scenarios: attempts, endpoints, terminal owner/outcome, duplicates before dedup, late data, cancellation/tombstones, epochs/retry batches, trace signatures, and cleanup counters.
- Re-run the 35 self-tests, policy verification, three fixture runs or equivalent published evidence checks, raw hashes, 15-member archive source-byte comparisons, copy parity, privacy scan, board validation, and diff check.
- Confirm no production runtime or numeric candidate changed and `TASK-260721-3miqh4` remains blocked on `TASK-260715-1gjxer` and `TASK-260715-1pn983` after this bug is accepted.
- Privacy is stop-the-line: no raw spawn log, AppleDouble entry, host/account/resolver/query identifier, token, or secret may be versionable.

Use only Codex Sol high. Do not delegate or use Claude. Mark the bug done only on an accepted verdict; otherwise return exact bounded rework.
