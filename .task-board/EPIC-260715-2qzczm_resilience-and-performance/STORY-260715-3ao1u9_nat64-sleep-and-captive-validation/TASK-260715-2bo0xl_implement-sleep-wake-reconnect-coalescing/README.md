# Implement sleep-wake reconnect coalescing and cancellation

## Description
Integrate sleep and wake lifecycle inputs with path and reconnect ownership so suspended work is invalidated safely, wake produces at most one current recovery generation, duplicate path events coalesce, and truthful capability returns within memory and cancellation bounds.

## Scope
In scope: sleep and wake notifications available to provider and shared core; pre-sleep snapshot; timer and attempt suspension or cancellation policy; wake path refresh; current generation; duplicate wake and path change coalescing; lane, relay, DNS, and association invalidation where required; reasserting; stable readiness; stop during sleep or wake; metrics; fake-clock tests. Out of scope: keeping sockets alive contrary to OS behavior, background execution guarantees, physical test execution, captive policy, route-mode implementation, UI process lifecycle, or final retry and energy tuning.

## Acceptance Criteria
1. Sleep records one current lifecycle event, prevents stale timers or network completions from publishing capability, and applies the documented resource retention or release policy within the memory ceiling. 2. Wake plus any accompanying path and viability changes starts at most one current reconnect sequence after obtaining a fresh path snapshot. 3. Old lanes, relay associations, settings completions, DNS transactions, and callbacks cannot resurrect the pre-sleep generation or deliver datagrams after invalidation. 4. Stop while asleep, stop during wake, rapid sleep and wake cycles, duplicate events, critical memory, and unavailable path cancel promptly and run one cleanup path. 5. Fake clock and platform tests cover every ordering and assert reasserting and capability timelines, retry counts, overlap reservations, observer and timer counts, route or DNS sentinels, and resource baselines.
