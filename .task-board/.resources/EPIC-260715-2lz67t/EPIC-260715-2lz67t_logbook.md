# EPIC-260715-2lz67t planning logbook

## 2026-07-15 — Protocol resource-limit mismatch

The supplied protocol v1 hello carries features and maxFrame, and the message table contains no limit-exchange message. The resource section nevertheless requires association count, queued bytes, datagram size, and idle timeout to be negotiated or capped. Guessing an extension could make old v1 peers misparse the stream.

Decision: create TASK-260715-18owh7 as an explicit blocking architecture decision. It must choose fixed local caps, a proven feature-gated compatible exchange, or a new version and update all schema, vector, UDP, capability, and documentation consumers.

## 2026-07-15 — Pre-execution checksum safety

The deployment text permits a protocol self-hash fallback, while the security invariant says a known mismatch never executes. Executing an unverified uploaded binary solely to ask it for its own hash would violate the stronger invariant.

Decision: TASK-260715-fve0hj requires allowlisted remote hash utilities or bounded readback with client-side SHA-256 before chmod-to-execute or launch. Self-hash remains secondary post-verification build-identity evidence.

## 2026-07-15 — DNS policy reuse

M1 already has TASK-260715-1tnjlu to choose the exit resolver and TASK-260715-5o6jqg to provide SSH DNS-over-TCP. M2 must not choose another resolver implicitly.

Decision: TASK-260715-2zmw58 consumes the approved M1 decision, and TASK-260715-3260rm integrates only that safe tunneled transport. Degraded mode is not usable if safe DNS is unavailable.

## 2026-07-15 — Milestone ownership

M2 relay reprobe is limited to a healthy authenticated base SSH transport. Network path, endpoint exclusion, route, lane-pool, NAT64, sleep, captive, and fail-closed recovery remain M3. M2 supply-chain scope ends at pinned source, four assets, hashes, bundle manifest, notices, scoped provenance, and reproducibility; signing, notarization, attestation, and release approval remain M5.

## 2026-07-15 — External handoff representation

Initial exact cross-epic task links correctly represented M0 and M1 prerequisites but caused task-board to reject the required planning to-review transition while those upstream epics remain at to-review. This is a workflow-state constraint, not evidence that prerequisites are optional.

Decision: preserve all 125 direct within-M2 links. Replace the 19 cross-epic edges with 14 task-ID-scoped precondition resources on the exact consumers, matching the established M1 decomposition pattern. Spawned implementers receive those resources and must verify the named upstream outcomes are accepted before production integration.

## 2026-07-15 — Diagram renderer anomaly

task-board plan --render --format png --layout phases failed because the local Graphviz dot binary references missing /opt/homebrew/opt/libtool/lib/libltdl.7.dylib. No workstation package change was authorized or required. The canonical plan, DOT source, and four PlantUML task diagrams are attached and remain reviewable as code.

## 2026-07-15 — Planning-only compliance

All board writes used task-board. No implementation, source, test, configuration, or specification edit was performed.