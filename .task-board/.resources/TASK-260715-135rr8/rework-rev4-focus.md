# TASK-260715-135rr8 CR rev4 focused rework

Resolve the CR rev3 reviewer finding without weakening the production evidence gate.

## Required outcome

- Keep the physical lifecycle row bounded to 500 cycles and keep the absolute maximum physical-footprint drawup ceiling at 256 KiB.
- Preserve fail-closed exact-working-tree and pinned-HEV-artifact provenance.
- Emit a cryptographically exact-tree-bound raw lifecycle artifact before returning a production-entry failure, so a failed attempt is independently auditable.
- Investigate the demonstrated allocator-timing ambiguity: one independent run had a bounded +180224 B physical-footprint rise with no observed decrease, while the next two runs passed.
- Do not accept a mere threshold widening, retry-until-green loop, arbitrary sleep, or removal of the release requirement.
- Prefer separating two distinct claims if evidence supports it: resident physical footprint must stay under the unchanged 256 KiB cap, while actual allocation/resource release should be proven with a deterministic live-allocation or lifecycle-owned-resource signal rather than depending on when Darwin returns allocator pages to the OS. Any new signal must be real, bounded, documented, covered by Swift Testing, and reported in raw evidence.
- If no clean deterministic release signal can be established, keep the gate failing and attach the bounded investigation evidence instead of forcing a pass.
- On a successful fix, produce three sequential, non-concurrent, independently passing exact-tree physical matrix runs with distinct run IDs and raw artifacts, plus focused tests, the full Swift suite with coverage, strict format/diff/privacy/safety checks, and an updated clean three-file CR patch applying to both the Story base and current `main`.
- Do not install, load, sign, or enable a Network Extension or VPN. Do not mutate routes, DNS, interfaces, packet filters, Keychain, or unrelated processes. SwiftPM/loopback HEV tests only.

Use only the existing Story worktree and preserve unrelated user/board changes. Leave the task at `to-review` with a new task-scoped outcome and CR revision; do not commit.
