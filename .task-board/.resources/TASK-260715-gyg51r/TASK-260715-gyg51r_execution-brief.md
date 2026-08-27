# Execution brief — physical MTU and socket-pressure matrix

Run the accepted TASK-260715-gyg51r scope on this arm64 macOS 26.5 host (128 GiB RAM) through ReluxTunnelHarness only. This host is authorized for bounded physical SPM-harness measurements, but not for a real system VPN.

Hard safety boundaries:

- Never load/start/install/sign a NetworkExtension provider and never create or modify VPN preferences, routes, DNS, interfaces, packet filters, launch daemons, or system extensions.
- No external SSH host or Internet traffic. Use deterministic local/loopback harness traffic and synthetic non-secret endpoints only.
- Do not invoke global memory-pressure tools, sudo, interactive authorization, Keychain, or commands that may disrupt unrelated processes. Induce pressure only inside bounded harness/socket settings with explicit memory/time ceilings and abort criteria.
- Record actual Apple-silicon hardware/macOS identity without stable device identifiers or secrets. If energy/NAT64/native-IPv6 evidence requires unavailable privileges/environment, mark the row unavailable with exact evidence; do not fabricate or weaken red rows.

Delivery:

Execute MTU 1500/4096/8500 under nominal, constrained-buffer, receiver-stall, and mixed local traffic. Capture requested/effective socket buffers, packet/byte/batch/drop/latency/CPU/syscall/fragmentation/max-datagram/resource-lifecycle evidence with reproducible commands and bounded raw artifacts. Require clean recovery and no monotonic task/descriptor growth. Recommend an injectable MTU/buffer range from measurements without changing production tuning or selecting a final physical policy. Preserve iPhone as ADR-024 deferred. Attach a TASK-scoped matrix/outcome and hand off to review.
