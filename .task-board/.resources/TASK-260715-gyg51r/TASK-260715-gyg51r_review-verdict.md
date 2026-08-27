# TASK-260715-gyg51r — independent review verdict

## Verdict

Changes requested. Route the task to `to-dev`; do not accept CR-TASK-260715-gyg51r-1 revision 1.

The candidate's nominal measurements and recommendation reproduce, but the safety and evidence gates do not satisfy the acceptance criteria or review focus.

## Findings

### F1 — High: output containment is bypassable through a symlink

Production call site: `MTUMatrixHarnessCommand.run(context:)` calls `MTUMatrixRunConfiguration.parse(_:)` before writing the report. The parser uses lexical `standardizedFileURL.path.hasPrefix` checks at `MTUMatrixCommand.swift:61-71`; it does not resolve symlinks or verify the destination parent after directory creation.

Independent negative probe:

- Created `.temp/TASK-260715-gyg51r-review/escape` as a symlink to `/tmp/TASK-260715-gyg51r-review-symlink-target`.
- Passed output `.temp/TASK-260715-gyg51r-review/escape/TASK-260715-gyg51r_symlink-escaped.json` through the real `swift run ReluxTunnelHarness mtu-matrix` entry point.
- The command exited `0` and created the file outside the declared `.temp` subtree. Evidence: `TASK-260715-gyg51r_review-symlink-escape.log`, SHA-256 `b679c5a08af735bc1d5fcf0cde550f8caa103c1004ff66a13944cf35c1e3ea8a`.
- The probe file, symlink, and external task-scoped directory were removed after capture.

Required rework: use resolved/no-follow containment appropriate to the output contract and add a production-entry negative test for the symlink escape, not only the direct absolute-path rejection in `HarnessTests.swift:298-315`.

### F2 — High: descriptor/task lifecycle metrics are not measurements

- `taskDelta` is hardcoded to `0` at `MTUMatrixCommand.swift:358`.
- `descriptorDelta` at lines `508-533` is the count of failed `close()` calls, not a before/after descriptor delta and not a monotonic-growth measurement.
- The end-to-end test at `HarnessTests.swift:375-376` merely asserts these emitted values. It cannot detect leaked extra descriptors/tasks.
- The producer outcome explicitly says the earlier process-level FD snapshot was removed and evidence was narrowed to two successful close calls. That proves owned closes, but it does not support the reported zero descriptor/task delta required by AC3 and the review focus.

Required rework: report these properties as unavailable/unsupported unless genuinely measured, and add a serialized repeated-run lifecycle test with an appropriate stable baseline that can detect monotonic owned-resource growth. Do not emit a fabricated zero.

### F3 — Medium: pressure validation does not prove a bounded, reason-specific outcome

`MTUMatrixAnalysis.validate` at lines `145-150` accepts every pressure row with any positive `drops`, even 100% loss, inconsistent `sendFailures + receiveQueueDrops`, a missing/incorrect reason, or counters exceeding attempts. Existing negative coverage only checks `drops == 0` (`HarnessTests.swift:336-341`).

The independent run observed very heavy but finite pressure effects: constrained received `88/4608` with `768` sender refusals and `3752` queue drops; receiver-stall received `314/4608` with `4294` queue drops. Whether these are acceptable requires an explicit measured bound/accounting invariant; the current gate would also accept materially worse or forged rows.

Required rework: define and enforce the intended pressure bounds and accounting/reason invariants, with negative tests that narrow the gate (100% loss, inconsistent counters, missing/wrong reason, and failed recovery) through the production analysis path.

### F4 — Medium: `batches` is derived, not observed

`batches` is emitted as `(sent + 31) / 32` at `MTUMatrixCommand.swift:338`, while the runner performs one `send` syscall per packet. No batch operation or grouping boundary is observed. README calls it a logical batch, but the raw schema name is unqualified and AC4 asks for batch metrics.

Required rework: either record actual batch operations/boundaries, rename the field to explicitly state that it is a derived logical grouping and document the formula, or mark real batching unavailable. Add a consistency test.

## Independent matrix result

- Host: physical Apple M3 Max Mac, arm64, macOS 26.5 build 25F71.
- Matrix: 36 unique rows, MTU `1500/4096/8500` × `ipv4/ipv6/dual-stack` × `nominal/constrained-buffer/receiver-stall/mixed`, 512 attempts per row.
- Nominal and mixed: `4608/4608` received for each pressure group, zero drops.
- Constrained: `88/4608` received, `768` errno-40 sender refusals, `3752` receiver-queue drops.
- Receiver stall: `314/4608` received, `4294` receiver-queue drops.
- Requested/effective send buffers reproduced at `4096`, `32768`, and `262144` bytes.
- Native IPv6 ran over `::1`. NAT64 is honestly unavailable, energy is honestly unavailable, and physical iPhone remains ADR-024 deferred-unavailable.
- Raw review matrix SHA-256: `128fe39bc265d4cb77658d35f79adca9fb84ad5fa51b480dc16ec6956c066f85`.

## Validation run by reviewer

- Independent 36-row matrix: exit `0`.
- Focused `ReluxTunnelHarnessTests`: 18 tests, exit `0`.
- Coverage for affected file: 86.15% regions, 87.95% functions, 96.67% lines; exit `0`.
- Full `swift test`: 467 tests in 40 suites, exit `0`, with 25 pre-existing declared known ReluxNIOSSH-unavailable issues.
- `swift format lint` on affected Swift files: exit `0`.
- Exact CR diff check: exit `0`; patch SHA-256 matches the CR (`a54802ca5ea1b33ad5793f790da6c0e715ad11fb775868a4af6628a8c2ae259b`).
- Source endpoint scan confirms only IPv4 `127.0.0.1` and IPv6 `::1` bindings; raw privacy sentinel scan found no configured profile UUID or secret classes.
- `task-board validate`: exit `0` before verdict routing.

## Rework acceptance

Re-review must reproduce all 36 rows and retain the green test/coverage/format gates, plus demonstrate: symlink-safe resolved output containment at the production entry point; honest lifecycle fields backed by repeatable measurement; negative pressure-accounting/bound tests; and an honest batch metric definition.
