# TASK-260715-1juybj validation and hashes

Date: 2026-07-21 (Asia/Tbilisi)

## Scope

Architecture/specification rework only. No implementation or test source was
changed. The contract, M0 capability trace, implementation-task brief,
task-scoped diagrams/renders, project logbook, and board outcomes were revised.

Rework 02 is narrower: only the normative ownership-sequence source/render,
validation/evidence resources, logbook, and board metadata change. The contract
and production source remain byte-identical. The corrected sequence places the
stopped/retired/pending-authentication-capacity close immediately after accept
and before any SOCKS bytes, while leaving wrong/stale capability and monotonic
deadline expiry inside authentication.

## Source-backed deadline audit

- `HEVSOCKSBoundary.swift:284-290` enforces the pending-descriptor count.
- `HEVSOCKSBoundary.swift:437-452` applies `SO_RCVTIMEO` only.
- `HEVSOCKSBoundary.swift:303-345` performs multiple receives and replies
  without one monotonic accept-time budget.
- `HEVSOCKSBoundary.swift:388-402` has no authentication-reply send deadline.

The contract now states exactly that current admission is count bounded and an
immediate non-owned no-auth client is rejected before handoff, while the current
timeout is per-receive inactivity rather than absolute. One monotonic
accept-to-authentication deadline and adversarial coverage are explicit M1
requirements assigned to `TASK-260715-b6uruh`.

## Validation

- `swift test --filter externalIngressRejected` — pass: one Swift Testing case,
  `external no-auth ingress is rejected before the adapter seam`, on the
  macOS-hosted target. The accepted non-fatal HEV alignment linker warning is
  unchanged. The evidence is intentionally not described as slow-trickle proof.
- `java -jar .temp/tools/plantuml.jar -checkonly` on both task-scoped `.puml`
  sources — pass with PlantUML 1.2026.6.
- `java -jar .temp/tools/plantuml.jar -tsvg -o artefacts` on both sources — pass
  using default Graphviz 14.0.4.
- Opaque render check — `rsvg-convert 2.61.3` generated a white-background
  1575 x 1349 RGB state PNG and a corrected 1921 x 1742 sequence PNG. Both were
  inspected at original resolution. In the corrected sequence, the entire
  stopped/retired/pending-full close-only branch, its no-reply/no-handoff note,
  the acquired-slot path, and the distinct wrong/stale/deadline authentication
  branch are legible and unclipped; all other labels and boundaries remain so.
- Toolchain anomaly/repair — initial Graphviz failed to load
  `libltdl.7.dylib`; `brew install libtool` installed `libtool 2.6.2` and
  `m4 1.4.21`, restoring the default renderer. No project dependency changed.
- `task-board q 'get(TASK-260715-b6uruh) { full }'` — brief now requires one
  accept-time monotonic deadline and deterministic slow-trickle,
  wrong-credential, both-reply-stall, cancellation, stale-generation,
  slot-recovery, descriptor-cleanup, iOS, and macOS rows.
- Existing dependency edge remains correct: `TASK-260715-b6uruh` is blocked by
  this contract and blocks lifecycle plus parser/fuzz consumers. No duplicate
  gap task was needed.
- `task-board validate` — `Board is valid. No issues found.`
- Diagram authored copies under `diagrams/` compare byte-identically with the
  resource-update inputs; rendered copies under `diagrams/artefacts/` do too.
- After board update, `task-board resource get` plus `cmp` passed for all nine
  authored/resource pairs: contract, M0 trace, state source/render, sequence
  source/render, validation, cumulative rework evidence, and rework-02 evidence.
  Downloaded hashes matched.
- `git diff --check` — pass.
- Spawn directive checkpoint — no directives recorded for
  `RUN-260721-2dc04e` before validation.

## Outcome hashes (SHA-256)

```text
55a2a87a4e53df101a07af6dbbef3c94ee73228a998e2a2fbe65eab112ceeb36  TASK-260715-1juybj_contract.md
a12b7b5484ade85e962a33c63c50aaf6bfa9937762c51458145813e8f8fe49b1  TASK-260715-1juybj_m0-capability-trace.md
cb749c03051f874482ccdc5d36ff4d5b45e72c4a71cbb226efb54b2f8c358595  TASK-260715-1juybj_flow-state.puml
aed480eb167681f148a1bac1222744e083f0617bf511dd860f88313ee8b9c7f5  TASK-260715-1juybj_flow-state.svg
43a8bcf3e66412d0ae89333ea4e64b74125b7d4a0d49d7c1d2ce18d212e1582f  TASK-260715-1juybj_ownership-sequence.puml
b6a4361121679a6eba5c732695880ec3002c8de1260020ee790a75720a812927  TASK-260715-1juybj_ownership-sequence.svg
7fd0d9a60c0a4f520e0a7c6673c300f7b95094b0bec0f0727cd901b22b355699  TASK-260715-1juybj_rework-evidence.md
71bf1d4aa49c7d09600ea821c4a1c3b2e98929898284be360c092d8a6cb7cc81  TASK-260715-1juybj_rework-02-evidence.md
```

Load-bearing inspected production-source hashes:

```text
8742e306c9625ab56e6745b956e853c96246c50eb56dd7c530f63962bae0cc2a  Sources/ReluxTunnelNativeAdapter/HEVSOCKSBoundary.swift
95dec4422724ddc93c201fd5dafc7af562a20a30e50186c0977f8705fb03542a  Sources/ReluxTunnelCore/SSHContracts.swift
```

Resource download comparison passed and is also recorded in the task note plus
rework handoff.
