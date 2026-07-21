# TASK-260715-3xpc6b independent review

Verdict: changes requested; route to to-dev.

## Blocking findings

1. Association admission and incarnation ownership occur after domain resolution. In relay/internal/udp/io.go:290-299, Send calls destination, which performs LookupNetIP at lines 559-623, before Registry.Ensure returns an AssociationToken. A domain send blocked in resolution can therefore outlive CloseAssociation: after the close removes the registry entry, the lookup completion calls Ensure and recreates the association with a new incarnation, then sends the stale datagram. The same path can attach old work to an independently reused ID. This violates the normative pre-side-effect order and the requirement that close, cancellation, and stale-incarnation work cannot reopen or mutate reused state. The current test suite covers stale generation receive work only at io_test.go:604-624; it has no barrier-controlled close/reuse-during-resolution test.

Required rework: reserve association capacity and obtain an incarnation-scoped token before starting resolution, then complete family/socket admission and send only if that exact token is still active. Association close/session loss/process cancellation must cancel or invalidate every pending resolver job, and deterministic tests must force close, expiry, cancellation, and same-generation ID reuse while resolution is paused and prove no send, reopen, reply, or resource leak.

2. Domain resolution is synchronous on the Send caller. Send directly invokes resolver.LookupNetIP and can block for ResolverTimeout, which accepts values up to 30 seconds at io.go:70-83. The only concurrency test avoids this by starting Send in a test goroutine at io_test.go:186-191. Production contains no bounded resolver worker/job scheduler or asynchronous completion seam. An event-loop caller would stall; a caller workaround using one goroutine per datagram is explicitly prohibited.

Required rework: provide bounded asynchronous resolver execution with fixed admission, worker/job, memory/result, deadline, and cancellation limits. Completion must be incarnation-checked before socket work. Add deterministic no-sleep tests proving the event-loop remains available, excess requests reject before spawning work, and all jobs/workers return to baseline.

3. Truncation is checked after source sockaddr conversion. system_io.go:48-56 converts and allocates the source endpoint before returning MSG_TRUNC. A truncated datagram with an unsupported or scoped sockaddr therefore becomes an association-terminal address failure instead of the required silent counted oversize/truncation drop, and source materialization occurs before the oversize gate.

Required rework: surface truncation immediately after recvmsg and before endpoint conversion/materialization; add a controlled test where truncation and an otherwise unsupported source coincide and verify a counted nonterminal drop.

4. IPv4-mapped IPv6 input is rejected only inside SendTo after Registry.Ensure has opened/admitted an IPv6 socket. io.go:543-548 treats every 16-byte address as IPv6, while system_io.go:33-35 rejects Is4In6. This violates the requirement that invalid/unsupported addresses perform no socket I/O or state admission.

Required rework: classify unsupported numeric forms before Registry.Ensure and add a no-resolver/no-socket/no-state test.

## Fresh verification

Green on the reviewed worktree:
- pinned Go 1.26.5 UDP tests, count=100;
- pinned Go race detector for UDP and protocol, count=10;
- full relay Go tests, vet, and build with CGO disabled;
- UDP coverage 84.3 percent;
- UDP test cross-compiles for linux/amd64, linux/arm64, and darwin/amd64;
- make relay-protocol-check;
- full Swift test suite, 318 tests, and swift build;
- gofmt diff, strict swift format lint, git diff check, privacy/prohibition scans, and task-board validate.

These gates establish build health but do not cover the required resolver/association interleavings above.