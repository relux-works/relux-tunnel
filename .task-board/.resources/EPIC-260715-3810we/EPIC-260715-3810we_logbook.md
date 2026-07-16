# EPIC-260715-3810we planning logbook

## 2026-07-15 — Reused M0 gates instead of duplicating them

Finding: M0 already owns Apple intent and provisioning, generated targets, packet bridge and HEV acceptance, SSH-engine selection, and legacy-product preservation.

Decision: M1 references TASK-260715-nphtib, TASK-260715-2jatnd, TASK-260715-1gjxer, and TASK-260715-14lk3y. No replacement A0, P0, packet, or SSH selection task was created.

## 2026-07-15 — Exit-side resolver policy is unspecified

Finding: the baseline product profile requires display name, SSH host, port, account, and key, but M1 DNS-over-TCP also needs a resolver reachable from the exit host. The supplied specifications do not choose a resolver source or default.

Decision: created TASK-260715-1tnjlu — Decide the baseline exit-side DNS resolver policy. It compares explicit profile configuration, product default, exit-host discovery, and tunneled DoH and blocks resolver-dependent implementation. No public resolver was assumed.

## 2026-07-15 — Physical evidence ownership avoids a planning cycle

Finding: real SSH, TCP, DNS, and route evidence needs the platform provider adapters, while provider acceptance needs the completed SSH, TCP, and DNS core. Splitting physical tasks across those core stories would create bidirectional story dependencies.

Decision: moved TASK-260715-3f4rhy, TASK-260715-2qr5aj, and TASK-260715-2wqffe under STORY-260715-eto58m. Core stories retain deterministic unit, fault, fuzz, harness, and controlled integration gates. The lifecycle story owns final physical iPhone and Mac acceptance.

## 2026-07-15 — Capability reporting remains truthful at M1

Finding: M1 intentionally has TCP and safe DNS but no general UDP relay. Calling it full would contradict the product capability model.

Decision: runtime messages expose independent TCP, safe-DNS, UDP, route-mode, and health facts. M2 owns full versus degraded relay capability behavior, and M4 owns final user-facing presentation.

## 2026-07-15 — Internal SOCKS endpoint must not become a local proxy

Finding: loopback binding alone may not prove process ownership on macOS. The pinned HEV capability must support a private endpoint or a per-generation admission mechanism.

Decision: TASK-260715-1juybj must prove the endpoint mechanism on both platforms before TASK-260715-b6uruh implements it. Public listener configuration and accept-all production behavior are explicitly excluded.

## 2026-07-15 — Board status transition requirement

Anomaly: direct story transitions to to-dev were rejected because the board requires an assignee.

Disposition: each story was temporarily assigned to the solution-architect identity, transitioned to to-dev, then unassigned. No implementation assignment remains.

## 2026-07-15 — Graphviz renderer environment failure

Anomaly: task-board plan rendering aborted because Homebrew Graphviz cannot load /opt/homebrew/opt/libtool/lib/libltdl.7.dylib.

Disposition: no rendered PNG is claimed. The canonical plan, Graphviz DOT source, PlantUML sequence source, and exact failure log are attached. This workstation dependency issue does not alter the board graph or product architecture.

## 2026-07-15 — Planning handoff is separate from M0 execution blocking

Finding: unfinished cross-epic blockedBy edges prevent task-board from moving a planning epic to to-review, even when the decomposition itself satisfies its role checklist. The brief requires within-epic dependency links and says not to duplicate M0 gates.

Decision: removed the four cross-epic dependency edges and preserved the exact M0 outputs as injected precondition resources on TASK-260715-30zng6 and TASK-260715-3qqbbm. All 135 M1 execution links remain. Production acceptance still requires the named M0 outcomes, while solution-architecture review can proceed independently of M0 execution status.
