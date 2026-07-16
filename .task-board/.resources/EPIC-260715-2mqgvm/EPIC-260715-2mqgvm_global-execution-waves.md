# Relux Proxy global execution waves

Date: 2026-07-15

## Interpretation

The project-level `task-board plan` shows when an epic may begin, not when every
task in that epic may run. The task graph is authoritative for execution. This
distinction preserves useful parallelism: credential-free CI can start after
M0 while signing, publication, App Review, and promotion remain blocked by
later technical and product evidence.

## Start waves

1. **M0 — viability and foundation.** Resolve Gate A0 and Gate P0, freeze the
   generated Apple target architecture, prove the public packetFlow/socketpair
   bridge on a physical iPhone, and select the in-process SSH engine.
2. **M1 plus the safe M5 CI subset.** Build the TCP/DNS system-VPN baseline.
   In parallel, define the CI trust boundary and add only credential-free
   validation foundations. No production credential, signing, upload, or
   publication task is released by this wave.
3. **M2 plus the safe M4 product subset.** Add the versioned relay, portable
   assets, UDP associations, and full/degraded capability model. Product work
   may begin from the accepted M1 profile, trust, lifecycle, and status
   contracts; screens requiring M2/M3 evidence remain task-blocked.
4. **M3 resilience and continued M4/M5 preparation.** Add lane scheduling,
   bounded windows and rekey, memory-pressure control, reconnect, QUIC policy,
   NAT64/sleep/captive behavior, and evidence-led tuning. Non-publishing release
   preparation may continue where its task prerequisites are satisfied.
5. **Release-candidate and publication tail.** Complete the physical product,
   security, accessibility, privacy, performance, and release matrices before
   macOS publication, TestFlight/App Review promotion, or rollback-watch tasks.
   The go/no-go record is a required outcome, not an implicit consequence of a
   successful workflow.

## Cross-phase gates represented in the board

- M1 runtime acceptance consumes M0 project, packet-plane, and SSH-engine
  outcomes (`TASK-260715-30zng6`).
- M2 protocol, HEV adapter, DNS, capability, bootstrap, and relay-session roots
  consume their exact M0/M1 decision tasks (`TASK-260715-111tde`,
  `TASK-260715-1loqwb`, `TASK-260715-28jdml`, `TASK-260715-30lv40`,
  `TASK-260715-3260rm`, `TASK-260715-2uipar`, and `TASK-260715-159pcp`).
- M3 lane, memory, reconnect, route, lifecycle, and tuning roots retain exact
  M0–M2 task dependencies; M4 profile, trust, status, and diagnostics roots
  retain exact M0–M3 dependencies.
- M5 CI may start from M0 gates, but relay staging, Apple distribution,
  privacy/review, promotion, and rollback are independently blocked by their
  required M2–M4 evidence.

## Planning status

All six epics are ready for planning review at `to-review`; all 31 stories are
development-ready at `to-dev`; all 321 implementation tasks remain unstarted
in `backlog`. These statuses describe planning readiness only. No service
implementation is authorized by this plan.
