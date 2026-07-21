# TASK-260715-3xpc6b independent rework review 02

Verdict: changes requested; route to to-dev.

## Blocking finding 1 — failed outbound sends refresh idle activity

The new activity-aware callback is bypassed by earlier registry touches. Numeric Send calls Registry.Ensure before sendWithToken (relay/internal/udp/io.go:334-346). For an existing family, ensureFamilies calls touch before returning (relay/internal/udp/registry.go:575-578); new or added-family admission also touches before the syscall (lines 602-612). Domain Send touches an existing association in Reserve before scheduling (lines 534-537), and resolver completion touches again in EnsureTokenFamilies before sendWithToken (lines 638-661). Only afterward does UseSocketOperation receive activity=false for EAGAIN (relay/internal/udp/io.go:357-363; registry.go:778-789).

Therefore outbound EAGAIN, ENOBUFS, and terminal send errors can rearm the idle timer even though no datagram left. This violates reviewer-focus item 2 and the execution brief requirement that EAGAIN/error not refresh association activity. The existing fake-clock readiness test covers receive-side EAGAIN only (relay/internal/udp/io_test.go:791-806); TestDatagramIOSendPressureAndTerminalCleanup checks disposition/resource count but not the deadline (lines 642-669).

Required rework: separate state/socket admission from activity, and touch an existing association only after a successful send. Add deterministic fake-clock tests for numeric and resolved-domain existing associations proving successful send refreshes activity while EAGAIN, ENOBUFS, resolver failure/cancellation, and terminal send error do not. Preserve the initial bounded lifetime of newly reserved socketless associations.

## Blocking finding 2 — scoped resolver results are silently rewritten

boundResolverResults accepts any IPv6 result after Is6 without rejecting a non-empty Zone (relay/internal/udp/resolver_scheduler.go:263-286). systemSocketOperations.SendTo converts that address with As16 into SockaddrInet6 but never sets ZoneId (relay/internal/udp/system_io.go:32-37). A scoped injected resolver result can therefore be selected and sent as the same 16 address bytes with scope zero, contrary to the no silent address rewriting or zone leakage review requirement.

Required rework: count zoned resolver results as discarded/unsupported before accepted-result byte credit and socket admission; add a controlled invalid-result test proving no descriptor/send side effect when no valid result remains and correct bounded fallback when a later in-cap unzoned result exists.

## Rework confirmed closed

Incarnation-first socketless reservation, fixed bounded resolver workers/jobs/completions, exact-token revalidation, close/expiry/replacement/reuse cancellation barriers, MSG_TRUNC-before-sockaddr precedence, mapped-IPv6 preflight, source/byte fidelity, finite mappings, fair per-turn budgets, privacy, and rootless/SSH-independent scope are present and covered.

## Fresh verification

Passed: pinned Go 1.26.5 UDP count=100; UDP+protocol race count=10; full relay Go tests; vet; CGO-disabled build; UDP coverage 84.3%; UDP test cross-build for linux/amd64, linux/arm64, darwin/amd64, darwin/arm64; make relay-protocol-check with 89 vectors and 57 Swift protocol tests; full 318 Swift tests; Swift build; strict Swift format; gofmt; git diff check; board validation; privacy/prohibition/resource scans.

One initial isolated race compile failed because the filesystem had insufficient free space. After deleting only the disposable cache created by this review and reusing the existing project cache, the identical race gate passed. This is environmental, not a product blocker.