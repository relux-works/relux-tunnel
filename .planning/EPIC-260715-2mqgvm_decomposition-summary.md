# EPIC-260715-2mqgvm — M0 viability and foundation decomposition

Date: 2026-07-15
Role: solution-architect
Planning scope: board decomposition only; no implementation or specification change.

## Outcome

- Refined all five existing stories with precise descriptions, explicit in-scope
  and out-of-scope boundaries, and independently verifiable acceptance criteria.
- Created 49 atomic backlog tasks. Every task has a human-readable title, a
  precise description, explicit scope and non-scope, numbered acceptance
  criteria, and three task-specific handoff checklist items.
- Added 85 task dependencies. Cross-story links escalate into a four-phase epic
  plan with Gate A0 and Gate P0 first.
- Added evidence, implementation, Swift Testing, fault-injection, fuzzing,
  physical-device, performance, memory, documentation, and decision-record work.
- Added a blocking decision task for the previously unspecified relay language
  and cross-build toolchain.
- Left every implementation task in backlog and performed no product-code work.

## Canonical execution gates

1. Phase 1 runs the two independent viability gates in parallel:
   - STORY-260715-2itwz7 — Gate A0: Apple packet-tunnel intended-use viability.
   - STORY-260715-2xnj3v — Gate P0: Apple capabilities and physical-device provisioning.
2. STORY-260715-l2i2oo — Generated Apple multi-target project foundation starts
   only after the authoritative Gate A0 and Gate P0 disposition tasks.
3. STORY-260715-jnpbyz — M0 packetFlow, socket-pair, and HEV bridge spike consumes
   the shared-core, native-linkage, and harness foundation.
4. STORY-260715-lkshfz — M0 in-process SSH engine comparison and selection consumes
   the project foundation. Its comparative scale and memory gate also waits for
   the measured packet-bridge and HEV memory baseline.

The focused execution-gate diagram is attached as
`EPIC-260715-2mqgvm_gate-dependency.dot`. The canonical task-board plan snapshot
is attached as `EPIC-260715-2mqgvm_canonical-plan.md`.

## Story task inventory

### STORY-260715-2itwz7 — Gate A0: Apple packet-tunnel intended-use viability (5)

- TASK-260715-1o3q6l — Compile the Gate A0 primary-source evidence dossier.
- TASK-260715-12avq0 — Author and internally review the Gate A0 disclosure packet.
- TASK-260715-1i6bh7 — Obtain authoritative Apple Gate A0 evidence.
- TASK-260715-x4h9n1 — Assess Gate A0 evidence and architecture pivot options.
- TASK-260715-1828xy — Record and publish the Gate A0 disposition.

### STORY-260715-2xnj3v — Gate P0: Apple capabilities and physical-device provisioning (8)

- TASK-260715-apc34w — Verify Relux Works Apple Developer account readiness.
- TASK-260715-ypo7yo — Define the Apple identifier and entitlement matrix.
- TASK-260715-3jloqy — Provision packet-tunnel App IDs and development profiles.
- TASK-260715-1jckn0 — Build the disposable iOS packet-tunnel entitlement probe.
- TASK-260715-1r0fxv — Build the disposable macOS packet-tunnel entitlement probe.
- TASK-260715-1kntdx — Verify Gate P0 on a physical iPhone.
- TASK-260715-9yp8to — Verify Gate P0 on a physical Apple-silicon Mac.
- TASK-260715-2ayxqn — Record and publish the Gate P0 disposition.

### STORY-260715-l2i2oo — Generated Apple multi-target project foundation (15)

- TASK-260715-1fv4z1 — Inventory the legacy project and migration invariants.
- TASK-260715-3r0993 — Select the project generator and deployment-target policy.
- TASK-260715-3bdplx — Select the relay language and cross-build toolchain.
- TASK-260715-32umrc — Record the generated-project architecture ADR.
- TASK-260715-2btjwm — Create the reproducibly generated workspace foundation.
- TASK-260715-uyju7n — Add the macOS host and packet-tunnel targets.
- TASK-260715-33oofa — Add the iOS host and packet-tunnel targets.
- TASK-260715-2nfz7w — Establish ReluxTunnelCore and thin platform-adapter boundaries.
- TASK-260715-1g9cyt — Add extension-safe native dependency packaging seams.
- TASK-260715-pmww4f — Add the ReluxTunnelHarness macOS CLI target.
- TASK-260715-1ccx3l — Add relux-relay and protocol-test target shells.
- TASK-260715-14lk3y — Preserve the legacy SwiftPM app and release path.
- TASK-260715-sbrrp7 — Add credential-free generated-project build validation.
- TASK-260715-nphtib — Execute the generated-project architecture verification matrix.
- TASK-260715-d6x51z — Document the generated-project workflow and migration boundaries.

The target dependency planning diagram is attached to TASK-260715-32umrc as
`TASK-260715-32umrc_target-dependency-plan.dot`.

### STORY-260715-jnpbyz — M0 packetFlow, socket-pair, and HEV bridge spike (10)

- TASK-260715-uopycx — Pin and audit the HEV and lwIP baseline.
- TASK-260715-p89bdj — Record the PacketFlowBridge concurrency and observability contract.
- TASK-260715-3o0co4 — Implement the public socket-pair PacketFlowBridge.
- TASK-260715-3dn813 — Add PacketFlowBridge unit and fault-injection tests.
- TASK-260715-1vv52g — Integrate unmodified HEV and lwIP with the bridge.
- TASK-260715-35wctc — Add HEV bridge integration tests.
- TASK-260715-52h8i3 — Add packet-frame fuzz and allocation-bound tests.
- TASK-260715-gyg51r — Run the physical MTU and socket-pressure matrix.
- TASK-260715-135rr8 — Run the physical memory, lifecycle, and concurrency matrix.
- TASK-260715-2jatnd — Record the M0 packet-bridge and HEV decision.

### STORY-260715-lkshfz — M0 in-process SSH engine comparison and selection (11)

- TASK-260715-28ok1k — Pin and audit the SSH engine candidates.
- TASK-260715-2ny6z4 — Record the SSH transport conformance contract.
- TASK-260715-nzdzv3 — Implement the minimal ReluxNIOSSH fork.
- TASK-260715-1af33i — Integrate the ReluxNIOSSH candidate adapter.
- TASK-260715-1ozsb6 — Integrate the libssh2 candidate adapter.
- TASK-260715-39xz9g — Provision reproducible SSH matrix fixtures.
- TASK-260715-2d3g5e — Add common SSH transport conformance tests.
- TASK-260715-3ikonq — Run the ReluxNIOSSH functional and rekey matrix.
- TASK-260715-1u2vpc — Run the libssh2 functional and rekey matrix.
- TASK-260715-2xx2tk — Run the comparative SSH scale, memory, and lifecycle matrix.
- TASK-260715-1gjxer — Record the M0 SSH engine selection.

## Decisions intentionally left to evidence-producing tasks

- Whether Apple accepts the disclosed local TCP termination plus SSH data plane,
  or requires a remote packet-semantic endpoint.
- The exact Relux Works bundle identifiers, shared groups, profiles, and whether
  both physical platforms pass Gate P0.
- The pinned generator version and exact minimum iOS and macOS deployment targets.
- The relay language, toolchain, cross-build strategy, and artifact contract.
- The measured MTU, socket buffers, batching limits, HEV session ceiling, and
  whether any HEV fork is justified by Instruments evidence.
- Whether ReluxNIOSSH or libssh2 passes every mandatory SSH gate, including
  configurable windows, rekey, real-server compatibility, memory, and lifecycle.

None of these is an untracked clarification gap. Each has an explicit blocking
task, evidence contract, downstream dependency, and decision record.

## Verification

- `task-board validate`: board valid, no issues found.
- Structured audit: 49 tasks, 49 unique names, zero default titles, zero missing
  descriptions, zero incomplete in/out scopes, zero placeholder acceptance
  criteria, zero missing task-specific checklists, and all tasks in backlog.
- Canonical plan: five stories across four phases; critical story path is Gate A0
  -> generated project -> packet bridge/HEV -> SSH engine selection.
- Graphviz rendering was not claimed because the installed `dot` binary cannot
  load Homebrew `libltdl.7.dylib`. The environment failure is attached as
  `EPIC-260715-2mqgvm_diagram-validation-01.log`; both DOT sources remain
  readable diagrams-as-code.

## Handoff state

All five stories are in `to-dev`; implementation tasks remain unstarted in
`backlog`. EPIC-260715-2mqgvm is handed to architecture review after checklist,
resource, status, and dependency verification.
