# Execute the generated-project architecture verification matrix

## Description
Independently run and review the foundation validation matrix on a clean environment, including generated target graph, dependency direction, Apple builds, native fixture linkage, harness lifecycle, relay artifacts, and legacy regression. Produce the evidence needed to accept the story architecture.

## Scope
In scope: clean detached clone of the current revision; deterministic Tuist generation; exact macOS-only target and scheme enumeration under ADR-024/ADR-027; unsigned Debug and Release host/provider builds; Swift Testing; native static archive and linkage inspection; harness lifecycle; relay artifacts; pinned legacy SwiftPM regression; and a second drift-free generation. Out of scope: every iOS target/build, production signing, installation or activation of a system extension/VPN, physical Gate P0, packet/SSH feature matrices, and fixing failures inside this verification task.

## Acceptance Criteria
1. A TASK-ID-scoped matrix records environment, public tool/SDK versions, source revision, exact commands, durations, privacy-safe artifacts, and pass/fail for every macOS foundation row. 2. The exact macOS-only target graph and dependency direction match accepted ADRs, while all deferred iOS targets/schemes are absent. 3. An isolated clean checkout runs the repository-owned credential-free entrypoint, a second clean generation is drift-free, and all applicable builds/tests pass. 4. Native linkage and nested bundle inspection prove universal architecture coverage, static/native policy, correct host/provider embedding, and no secret material. 5. No command installs, opens, saves, activates, or starts a real VPN on this build host. 6. Every failure creates or references concrete board rework; pass is claimed only after clean rerun evidence.
