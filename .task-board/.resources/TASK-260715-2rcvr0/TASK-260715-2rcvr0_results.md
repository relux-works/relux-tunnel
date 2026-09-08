# TASK-260715-2rcvr0 handoff — revision 2

## Outcome

The developer/operator guide documents the implemented M1 ownership boundary,
startup and reverse cleanup, versioned commands, state and independent
capability facts, diagnostic privacy, error mapping, troubleshooting, test
entry points, migration isolation, and concrete M2–M5 extension seams. README,
the Core boundary guide, LOGBOOK, one focused PlantUML source, and its four SVG
pages provide discoverability and durable evidence.

The guide explicitly records the implementation boundary: shared runtime and
the M0-bound macOS production factory are implemented and tested, while the
checked-in generated macOS `PacketTunnelProvider` remains a shell that does not
instantiate `MacOSProviderCompositionRoot`. Build success is not presented as
live composition evidence. M1 reports TCP plus safe DNS as
`connectedDegraded`, with UDP false; it is never labelled full UDP capability.

## Changes-requested rework

CR revision 1 correctly found that the partial-failure page drew packet
activation after failed settings applies with `committed` or `uncertain`
disposition. The revised page now distinguishes all production paths:

- `notCommitted` apply failure: no activation and no settings clear;
- `committed` or `uncertain` apply failure: no activation, settings clear;
- successful committed apply followed by activation failure: settings clear.

`TunnelRuntimeCoordinator.runStartup` is the production call site: every apply
error is mapped and thrown before the packet-read transition; only a successful
apply reaches `activateReads`. The focused coordinator suite attacks the bound
with all three dispositions plus packet-activation failure.

## Validation rerun after rework

All accepted reruns exited 0:

- `swift test --filter TunnelRuntimeCoordinatorTests`: 22 tests in one suite,
  including the named disposition negative test and activation rollback;
- PlantUML `-checkonly`, four-page SVG regeneration, temporary PNG rendering,
  and direct visual inspection of every page;
- local documentation links: 52 checked, 0 missing;
- production symbol/call-site and board handoff/dependency audits;
- explicit generated-provider negative check: file readable, composition symbol
  search exited 1 (verified absence, not a failed read);
- `git diff --check` and untracked text whitespace audit.

An attempted display-name Swift filter exited 0 but selected zero tests. It was
rejected as evidence and replaced by the 22-test suite rerun.

## Accepted attached evidence for unchanged scope

The revision-1 reviewer independently reran eight focused Swift filters (105
tests), `make m1-runtime-harness-test` (six tests and seven fixture scenarios),
both SwiftPM adapter target builds, generated macOS host/provider Debug and
Release builds, negative production-entry checks, and M2–M5 board-reference
resolution. This evidence remains applicable because the review rework changes
only the lifecycle diagram and its rendered pages plus the rework log entry;
production code and documented commands did not change.

## Artifacts and logs

- `docs/m1-runtime-ownership-and-operations.md`
- `diagrams/TASK-260715-2rcvr0_m1-runtime-lifecycle.puml`
- `diagrams/artefacts/TASK-260715-2rcvr0_m1-runtime-lifecycle*.svg`
- `.temp/TASK-260715-2rcvr0/research-runtime-verification.md`
- `.temp/TASK-260715-2rcvr0/swift-runtime-coordinator-rework-02.log`
- `.temp/TASK-260715-2rcvr0/plantuml-check-04.log`
- `.temp/TASK-260715-2rcvr0/plantuml-svg-03.log`
- `.temp/TASK-260715-2rcvr0/documentation-link-audit-03.log`
- `.temp/TASK-260715-2rcvr0/dependency-handoff-audit-02.log`

## Scope and completeness

No implementation behavior, future mode promise, board element, dependency, or
research task was added. The existing atomic documentation task and its three
completed prerequisites remain the smallest decomposition. The generated
provider wiring anomaly is documented rather than changed because implementation
work is expressly out of scope.
