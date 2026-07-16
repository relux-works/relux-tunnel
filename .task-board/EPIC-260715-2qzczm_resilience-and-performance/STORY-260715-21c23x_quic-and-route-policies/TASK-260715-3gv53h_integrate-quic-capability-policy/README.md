# Integrate Allow, Block, and Auto QUIC with capability generations

## Description
Integrate profile QUIC policy, UDP/443 classification, Auto evaluation, current relay capability, local fast failure, and association admission so every runtime state produces the contractually correct generation-safe behavior and diagnostics.

## Scope
In scope: policy profile snapshot; current full, degraded, reasserting, failed, and stopping capability; Allow relay admission; Block rejection; Auto evaluator; generation replacement; existing association disposition from M2 contract; mode change; cancellation; aggregate metrics and provider snapshot fields. Out of scope: route settings, final UI, packet payload inspection, preserving associations across relay generations, changing relay protocol, physical fallback, or threshold tuning.

## Acceptance Criteria
1. Allow opens new UDP/443 only through a current full relay-capable generation, Block always returns bounded local failure, and Auto applies one current evaluator decision before association admission. 2. Degraded, reasserting without current UDP, failed, stopping, relay loss, and stale generations cannot create new UDP/443 associations or a physical fallback. 3. Profile or policy generation changes affect new flows atomically, handle pending admissions deterministically, and dispose existing associations exactly as the recorded M2 policy specifies without migrating them. 4. Snapshot and metrics distinguish configured policy, effective outcome, finite reason, counts, and failure latency without destinations, queries, payloads, or application identity. 5. Integration tests cover all policies and states, relay loss and restoration, rekey and lane health changes, mode change races, pending or existing associations, cancellation, stale callbacks, and cleanup.
