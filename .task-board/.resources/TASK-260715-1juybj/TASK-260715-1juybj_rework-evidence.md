# TASK-260715-1juybj — rework 01 evidence

Date: 2026-07-21 (Asia/Tbilisi)

## Verdict closure

### 1. Authentication-deadline evidence corrected

The contract and M0 capability trace now distinguish current source from the
M1 production requirement:

- `HEVSOCKSBoundary.swift:284-290` bounds the pending descriptor set.
- `HEVSOCKSBoundary.swift:437-452` installs only `SO_RCVTIMEO`.
- `HEVSOCKSBoundary.swift:303-345` performs multiple blocking receives and
  replies without carrying one monotonic accept-time budget.
- `HEVSOCKSBoundary.swift:388-402` sends replies without a send deadline.

Therefore current code proves count-bounded admission and immediate no-auth
rejection before handoff, but not an absolute accept-to-authentication
deadline. A slow trickle can restart the receive inactivity interval, and a
client that stops reading a reply is not bounded by the current option.

The production contract now makes the missing behavior an explicit M1
decision: capture one monotonic deadline at accept and apply only its remaining
budget to all greeting and RFC 1929 reads, method/authentication replies, both
credential comparisons, cancellation, and stale-generation checks. Progress,
partial I/O, `EINTR`, and readiness wakeups cannot extend it. Expiry releases
the pending slot and descriptor once and prevents adapter handoff.

`TASK-260715-b6uruh` — **Implement the private SOCKS endpoint and bounded
CONNECT parser** — now has development-ready description, scope, six AC, and
two explicit checklist rows for this change. Its deterministic shared and
iOS/macOS provider-sandbox matrix must cover greeting/auth slow trickle, wrong
credentials, method/authentication reply stall, cancellation at every phase,
stale generation, pending-slot recovery, and descriptor cleanup. Its existing
dependency on this contract remains the correct blocking edge; no new task or
dependency is needed.

### 2. State render repaired and inspected

The unreliable `!pragma layout smetana` workaround was removed. The state
source now uses PlantUML's default Graphviz layout with short edge labels and
separate explanatory notes. The ownership sequence explicitly contrasts the
current receive-inactivity behavior with the M1 monotonic deadline.

Toolchain repair and versions:

- Initial `dot -V` failed because Graphviz 14.0.4 could not load
  `/opt/homebrew/opt/libtool/lib/libltdl.7.dylib`.
- `brew install libtool` installed `libtool 2.6.2` and dependency `m4 1.4.21`;
  this was the minimal repair needed to restore the default renderer.
- PlantUML: `1.2026.6`; Graphviz: `14.0.4`; `rsvg-convert`: `2.61.3`.

Exact checks:

```text
java -jar .temp/tools/plantuml.jar -checkonly \
  diagrams/TASK-260715-1juybj_flow-state.puml \
  diagrams/TASK-260715-1juybj_ownership-sequence.puml
PASS

java -jar .temp/tools/plantuml.jar -tsvg -o artefacts \
  diagrams/TASK-260715-1juybj_flow-state.puml \
  diagrams/TASK-260715-1juybj_ownership-sequence.puml
PASS

rsvg-convert --background-color white --format png \
  --output .temp/TASK-260715-1juybj/TASK-260715-1juybj_flow-state_opaque.png \
  diagrams/artefacts/TASK-260715-1juybj_flow-state.svg
PASS: 1575 x 1349 RGB PNG
```

The opaque PNG was inspected at original resolution. `Authenticated`,
`Reserved`, `Parsing`, `Opening`, `Replying`, `Streaming`,
`HalfClosedLocal`, `HalfClosedRemote`, `HalfClosedBoth`, and `Terminal` are
fully rendered. Every transition label (`exclusive handoff`, reservation,
failure, channel ownership, success reply, local/SSH EOF, abort, graceful
close, and cleanup) is visible, separated, and unclipped. All four explanatory
notes and diagram boundaries are visible. The 1635 x 1528 opaque ownership
sequence was also inspected; its deadline note and all participants/messages
are legible and unclipped.

## Focused and structural validation

- `swift test --filter externalIngressRejected` — pass: one Swift Testing case,
  `external no-auth ingress is rejected before the adapter seam`, on the
  macOS-hosted package target. The accepted non-fatal HEV alignment linker
  warning remains unchanged. This test proves immediate no-auth rejection, not
  the downstream slow-trickle guarantee.
- `task-board validate` — `Board is valid. No issues found.`
- `git diff --check` — pass.
- Spawn checkpoint — no directives recorded for `RUN-260721-1e6310` before
  validation.

## Outcome hashes and board-copy verification

```text
55a2a87a4e53df101a07af6dbbef3c94ee73228a998e2a2fbe65eab112ceeb36  TASK-260715-1juybj_contract.md
a12b7b5484ade85e962a33c63c50aaf6bfa9937762c51458145813e8f8fe49b1  TASK-260715-1juybj_m0-capability-trace.md
cb749c03051f874482ccdc5d36ff4d5b45e72c4a71cbb226efb54b2f8c358595  TASK-260715-1juybj_flow-state.puml
aed480eb167681f148a1bac1222744e083f0617bf511dd860f88313ee8b9c7f5  TASK-260715-1juybj_flow-state.svg
10bd0aee120939f117011f0dcbdf0ccfd13d3b1f4d5c4e3c069abbc275e3fc96  TASK-260715-1juybj_ownership-sequence.puml
781e2dbe822b3bb8b4aee06c69973efa31e98dc82f1d1e45eeab21c52e25724e  TASK-260715-1juybj_ownership-sequence.svg
```

Load-bearing source hashes remain:

```text
8742e306c9625ab56e6745b956e853c96246c50eb56dd7c530f63962bae0cc2a  Sources/ReluxTunnelNativeAdapter/HEVSOCKSBoundary.swift
95dec4422724ddc93c201fd5dafc7af562a20a30e50186c0977f8705fb03542a  Sources/ReluxTunnelCore/SSHContracts.swift
```

After resource update, `task-board resource get` materialized the contract,
M0 trace, two PlantUML sources, two SVG renders, validation, and this rework
evidence under `.temp/TASK-260715-1juybj/verify/`. `cmp` passed for all eight
source/resource pairs, and downloaded SHA-256 values matched the authored
values above (with validation and this evidence verified against their exact
uploaded bytes).

## Rework 02 — pending admission ordering

The normative ownership sequence now separates TCP `accept` from SOCKS bytes.
Immediately after accept/socket setup, already-stopped, generation-retired, or
pending-authentication-full admission closes the descriptor, emits neither a
SOCKS5 method reply nor an RFC 1929 reply, and never enqueues authentication or
hands the descriptor to the adapter. Only the acquired-slot branch reads the
greeting and RFC 1929 request. Wrong/stale capability and monotonic-deadline
expiry remain inside that authentication branch with the contract's
phase-and-budget-conditional safe reply behavior.

This ordering matches `HEVSOCKSBoundary.swift:284-299` and contract section
4.1 (`TASK-260715-1juybj_contract.md:185-191`). The separate post-handoff
`Adapter resource registry` branch remains unchanged semantically: it is the
bounded adapter flow/parser/open reservation, not the boundary's pending-auth
slot. No production code or other review-passing clause changed.

PlantUML 1.2026.6 syntax/render checks passed. The corrected white-background
RGB render is 1921 x 1742 and was inspected at original resolution: the entire
pre-negotiation close branch, its no-reply/no-handoff note, the acquired-slot
branch, and the distinct authentication failure branch are legible and
unclipped. The focused `externalIngressRejected` test again passed one test in
one suite; the accepted HEV alignment linker warning was unchanged.
