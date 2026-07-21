# TASK-260715-sdnk2k accepted review

Verdict: accepted.

## Architecture and acceptance evidence

- Each direction retains exactly one optional Data value plus an offset. A new read is issued only after the current value drains.
- Caller-validated local and remote chunk limits and the SSH write-call limit bound every pump operation. The shared non-waiting reservation actor enforces a checked per-flow sum and aggregate concurrent ceiling.
- Partial writes advance once, local would-block waits for injected readiness, SSH write suspension remains inside the accepted SSHByteChannel seam, and bounded readiness wakeups prevent busy spin.
- Operation and byte fairness slices invoke the injectable scheduler before another bounded slice, while tests demonstrate concurrent lifecycle progress.
- Cancellation uses one locked control claim, wakes local readiness, cancels structured children, calls channel cancel once, rejects late completions after every suspension, joins both pumps, and releases the aggregate reservation once.
- Terminal and diagnostic schemas are finite and candidate-neutral; Core contains no SSH engine dependency, detached task, unbounded stream, payload label, endpoint label, or free-form error field.

## Independent verification

- swift test --filter BoundedFullDuplexBytePumpTests: passed, 12 tests.
- swift test --sanitize=thread --filter BoundedFullDuplexBytePumpTests: passed, 12 tests, no sanitizer report.
- Producer log inspected: 20 repeated seeded integrity runs passed.
- make validate-core: passed, 288 tests in 26 suites plus swift build.
- swift format lint --strict --recursive Sources Tests Package.swift: passed.
- git diff --check, focused source whitespace check, Core boundary check, prohibited construct scan, and task-board validate: passed.
- Recorded hashes, fixed 450-byte canonical reservation, 64-byte concurrent ceiling, and 100-run cleanup baseline match the implementation tests and outcome evidence.

No acceptance-blocking findings remain.