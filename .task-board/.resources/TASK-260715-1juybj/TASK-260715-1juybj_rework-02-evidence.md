# TASK-260715-1juybj — rework 02 evidence

Date: 2026-07-21 (Asia/Tbilisi)

## Finding closed

The normative ownership sequence now matches the source-backed admission order:

1. The boundary accepts and configures the TCP descriptor.
2. It immediately checks stopped/retired state and the pending-authentication
   ceiling (`HEVSOCKSBoundary.swift:284-294`).
3. Rejection at that check closes the descriptor immediately, emits no SOCKS5
   method reply and no RFC 1929 reply, never enqueues authentication work, and
   never hands the descriptor to `SSHProxyAdapter`.
4. Only an acquired pending slot can enter method negotiation and RFC 1929.
   Wrong/stale capability and monotonic-deadline expiry stay in this branch,
   using the contract's phase-and-remaining-budget conditional safe reply.

This also matches contract section 4.1, especially lines 185-191. The later
`Adapter resource registry` remains a separate post-handoff bounded reservation;
it is not the boundary pending-authentication ceiling. No implementation code or
other review-passing contract clause changed.

## Render and inspection

- PlantUML 1.2026.6 `-checkonly`: pass for both task-scoped sources.
- PlantUML default Graphviz 14.0.4 SVG render: pass for both sources.
- `rsvg-convert` 2.61.3 opaque conversion: corrected ownership PNG is
  1921 x 1742 RGB.
- Original-resolution inspection: the stopped/retired/pending-full guard,
  immediate close, explicit no-method/no-auth-reply note, acquired-slot path,
  and separate wrong/stale/deadline authentication branch are fully legible and
  unclipped; all remaining messages and diagram boundaries are also legible.

## Focused and structural checks

- `swift test --filter externalIngressRejected`: pass, one test in one suite;
  accepted non-fatal HEV alignment linker warning unchanged.
- `task-board validate`: pass.
- `git diff --check`: pass.
- Spawn directive checkpoint: no directives recorded for
  `RUN-260721-2dc04e` before correction and render inspection.

## Corrected artifact hashes

```text
43a8bcf3e66412d0ae89333ea4e64b74125b7d4a0d49d7c1d2ce18d212e1582f  TASK-260715-1juybj_ownership-sequence.puml
b6a4361121679a6eba5c732695880ec3002c8de1260020ee790a75720a812927  TASK-260715-1juybj_ownership-sequence.svg
```

After board resource updates, all nine task-authored/resource pairs were
downloaded and compared byte-for-byte; SHA-256 values matched the authored
copies.
