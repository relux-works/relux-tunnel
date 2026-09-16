# STORY-260908-h39ajh: repair-shared-runtime-hosted-delivery-gates

## Description
Repair the reproduced repository CI blockers preventing signed Shared Runtime PR 6 from landing, without weakening board completeness or runtime supply-chain protections.

## Scope
Only the reproduced CI validation/scanner boundaries, narrow regression tests, and exact-head PR delivery. Preserve accepted runtime and signatures; no VPN operations.

## Acceptance Criteria
The real hosted failing entrypoints pass for PR 6 after reviewed repairs; negative fixtures still reject genuine incomplete board elements and runtime code downloads; exact signed head passes review and hosted checks before remote main advances.
