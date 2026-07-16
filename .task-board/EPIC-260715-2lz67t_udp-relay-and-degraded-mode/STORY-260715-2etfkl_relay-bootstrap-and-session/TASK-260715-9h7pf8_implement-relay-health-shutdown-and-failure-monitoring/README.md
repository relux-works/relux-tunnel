# Implement relay health, shutdown, and process-failure monitoring

## Description
Supervise the established relay generation with bounded PING or PONG health, exec-channel and process lifecycle events, graceful protocol close, forced cancellation, typed failure reasons, and one terminal callback that invalidates consumers.

## Scope
In scope: monotonic health clock; one outstanding bounded probe policy; opaque token correlation; configurable idle and response deadlines; channel EOF and error; remote process exit status; protocol framing failure signal; lane-A loss; graceful CLOSE_SESSION and stdin EOF; provider stop; forced timeout; generation identity; association invalidation callback; aggregate health metrics. Out of scope: deciding tunnel degraded state, opening replacement SSH lanes, network path reconnect, UDP socket cleanup internals, process restart policy, logging remote stderr verbatim, and user-facing retry controls.

## Acceptance Criteria
1. A healthy session sends probes only under the documented schedule, accepts only the matching bounded PONG, and cannot accumulate multiple probes, timers, or unbounded health payloads. 2. Missed health deadline, EOF, nonzero exit, channel error, framing failure, lane loss, identity violation, and provider stop produce one typed terminal event for the active generation. 3. Graceful stop sends CLOSE_SESSION when writable, closes stdin, observes the bounded exit deadline, then force-cancels without delaying provider cleanup indefinitely. 4. Late PONG, exit, timer, or channel callbacks from an old generation cannot revive health, emit a second failure, or touch replacement state. 5. Fake-clock and controlled-process tests cover healthy idle and traffic, stall, abrupt exit, crossed close, cancellation, repeated start or stop, timer cleanup, and privacy-safe counters.
