# TASK-260715-3xpc6b rework 02 results

## Closed findings

- Existing association reservation and numeric/token-scoped family admission no longer refresh idle activity. New state keeps one bounded initial deadline; successful socket activity is the only subsequent refresh.
- Injected-clock tests assert exact deadlines and timer-arm epochs for numeric and resolved-domain success, `EAGAIN`, `ENOBUFS`, resolver failure, caller cancellation, and terminal socket failure. Both `Ensure` and token-scoped IPv4-to-IPv6 family attachment paths are exercised, with registry and resolver resources returned to baseline.
- Resolver IPv6 results with zones are discarded before unmapping, accepted-result byte accounting, descriptor admission, or send. Scoped-only output performs zero descriptor/send work and cleans the reservation; a later unzoned in-cap IPv6 result is selected without rewriting. The system socket seam rejects a zoned address defensively.

## Verification

- Go 1.26.5 UDP `count=100` and UDP/protocol race `count=10`: passed.
- Full relay Go tests, vet, CGO-disabled build: passed.
- UDP statement coverage: 85.5%.
- UDP tests cross-built with CGO disabled for linux/amd64, linux/arm64, darwin/amd64, and darwin/arm64.
- `make relay-protocol-check`: passed with 89 vectors and 57 Swift protocol tests.
- Full Swift suite: 318 tests passed; Swift build and strict recursive Swift formatting passed.
- Pinned gofmt, diff, privacy/prohibition/resource scans, and `task-board validate`: passed.
