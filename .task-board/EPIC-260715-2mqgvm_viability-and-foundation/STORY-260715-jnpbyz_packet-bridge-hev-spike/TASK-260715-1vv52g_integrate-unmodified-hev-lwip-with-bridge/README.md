# Integrate unmodified HEV and lwIP with the bridge

## Description
Build the pinned unmodified HEV stack for the harness and both Apple provider configurations, hand it the owned socket-pair endpoint, apply the fixed UDP-in-TCP and low-memory baseline, and expose its process-local SOCKS side to an injectable adapter seam.

## Scope
In scope: reproducible HEV builds; descriptor handoff; config generation; MTU input; socks5.udp tcp; task-stack-size 24576; tcp-buffer-size 4096; max-session-count 1200 baseline; process-local SOCKS listener or owned channel; startup health; coordinated shutdown; metrics and notice bundling. Out of scope: SSHProxyAdapter implementation, final memory constants, remote relay, fork patches, production routes and DNS, and acceptance of external SOCKS clients.

## Acceptance Criteria
1. The exact pinned HEV sources build and link through the approved native packaging seam for macOS harness, macOS provider, iOS simulator, and iOS device configurations. 2. HEV receives only the bridge-owned endpoint and starts with the recorded MTU and exact UDP-in-TCP and low-memory configuration values. 3. The internal SOCKS endpoint is process-local or otherwise cryptographically or structurally restricted to the owned adapter path and rejects an external ingress test. 4. Startup failure and cancellation close HEV tasks, the transferred descriptor, listener state, and bridge resources without double close. 5. Required HEV, core, task-system, and lwIP notices are present in produced test bundles and trace to the pinned manifest.
