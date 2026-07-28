## Approved M0 SSH viability decision

Date: 2026-07-28

The human approved M0 viability scope: preserve pre-auth host-key verification, approved authentication, direct-tcpip, exec/stdin upload, client-rekey trigger, bounded lifecycle, privacy-safe errors, and available observability. Defer consumer-driven receive-credit semantics, RFC channel-open reason taxonomy, exact exec-exit metadata, and deep rekey/keepalive instrumentation to M3 evidence-gated work.

libssh2 is the primary candidate. ReluxNIOSSH remains recorded comparative evidence and must not receive further fork work unless new evidence invalidates libssh2.

This decision does not waive security, bounded-memory, host verification, authentication, direct-tcpip, cancellation, or lifecycle evidence.
