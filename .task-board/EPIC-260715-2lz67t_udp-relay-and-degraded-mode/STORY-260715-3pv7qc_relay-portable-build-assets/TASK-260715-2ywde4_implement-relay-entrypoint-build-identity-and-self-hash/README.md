# Implement the relay entrypoint, build identity, and self-hash contract

## Description
Implement the minimal rootless executable boundary required by packaging and bootstrap: exact stdio launch, protocol selection, privacy-safe build identity, self-hash verification path, diagnostic separation, signal or EOF shutdown, and rejection of unsupported invocation.

## Scope
In scope: relux-relay executable entrypoint; --stdio and --protocol 1; version and build identity query approved by the binding contract; self-hash using the running executable bytes where supported; bounded argument parsing; stdin and stdout ownership; stderr diagnostics; exit codes; EOF, termination, and cancellation; umask-respecting runtime files if any; no listener or daemon mode. Out of scope: UDP association behavior, remote upload, shell command construction, app bundle manifest generation, service installation, privileged operations, and arbitrary diagnostic or interactive commands.

## Acceptance Criteria
1. The relay starts protocol mode only for the exact supported stdio and protocol invocation and rejects unknown, duplicated, missing, or oversized arguments with a stable exit code. 2. Protocol stdout contains only the handshake and framed bytes; all human diagnostics use stderr and contain no payload, domain, destination, credential, or raw command stdin. 3. Build identity and self-hash output or handshake fields are deterministic, bounded, machine-parseable, and match the bytes selected by the bundle manifest. 4. The process never daemonizes, binds a public listener, requests elevated privilege, writes outside explicitly owned temporary state, or leaves children after EOF, signal, or cancellation. 5. Entry-point tests cover supported commands, malformed arguments, closed streams, signals, self-hash mismatch fixtures, stdout contamination, and repeated clean exit on all available targets.
