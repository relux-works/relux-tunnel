# Record the SSH transport conformance contract

## Description
Translate the SSH transport specification into a candidate-neutral implementation and test contract for connection, host verification, authentication, direct-tcpip, exec, windows, rekey, backpressure, cancellation, metrics, and lifecycle.

## Scope
In scope: Swift async interface and state ownership; raw host-key evidence before acceptance; supported auth outcomes; destination and originator endpoints; byte-channel and exec semantics; bounded write contract; half-close; per-channel receive windows and adjustment; client byte and time rekey; server rekey; keepalive; cancellation; error taxonomy; metric schema; lane identity for experiments; dependency injection. Out of scope: choosing a candidate, production lane scheduling, flow migration, SFTP, ProxyJump, interactive UI, relay framing, and final window constants.

## Acceptance Criteria
1. A TASK-ID-scoped contract defines every operation, state transition, cancellation point, timeout, ownership boundary, error, metric, and privacy rule required by the M0 matrix. 2. Host-key bytes, algorithm, and fingerprint evidence are available to policy before authentication acceptance, including first-use, match, and change cases. 3. Direct-tcpip and exec channels have explicit open, bounded write, read, EOF, half-close, reset, cancel, and close semantics. 4. Window policy, WINDOW_ADJUST, automatic byte and time rekey, explicit test trigger, server rekey, keepalive, and key-exchange channel behavior are independently observable. 5. The conformance contract can be implemented by either candidate without exposing candidate types to ReluxTunnelCore consumers.
