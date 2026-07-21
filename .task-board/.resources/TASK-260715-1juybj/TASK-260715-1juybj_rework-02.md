# TASK-260715-1juybj rework 02

Resolve the sole remaining finding in `TASK-260715-1juybj_rework-01-review-verdict.md`.

- In the normative ownership sequence, move pending-capacity and already-stopped/generation-retired rejection to immediately after TCP accept and before SOCKS method negotiation. This branch closes the descriptor immediately, sends no SOCKS5 method reply and no RFC 1929 reply, and never hands the descriptor to authentication/adapter work.
- Keep wrong/stale capability and monotonic-deadline expiry in the authentication branch with the contract's conditional safe reply behavior.
- Check the corrected ordering against `HEVSOCKSBoundary.swift` and contract section 4.1. Do not change production code or any already review-passing contract clause.
- Re-render the ownership SVG, convert to an opaque PNG, inspect the exact corrected branch and all labels at original resolution, update the outcome resource, validation, rework evidence, descriptions/hashes as needed, and run PlantUML syntax/render, board/resource-copy verification, and `git diff --check`.

Attach concise rework-02 evidence and route to `to-review`; do not self-accept.
