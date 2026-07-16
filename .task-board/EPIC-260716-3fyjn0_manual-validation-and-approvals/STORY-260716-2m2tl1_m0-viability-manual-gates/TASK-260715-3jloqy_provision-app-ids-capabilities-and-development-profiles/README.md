# Provision packet-tunnel App IDs and development profiles

## Description
Create the four approved App IDs, shared groups, packet-tunnel capabilities, and development provisioning profiles in the Relux Works Apple Developer account. Preserve reproducible non-secret metadata and validate each downloaded profile against the approved matrix.

## Scope
In scope: Apple Developer portal mutations for the approved identifiers; packet-tunnel, App Group, and Keychain capabilities; development certificates selected by authorized operators; device inclusion; profile generation and download; profile UUID, team, application identifier, entitlement, device, and expiry inspection. Out of scope: committing profiles or certificates, creating distribution or Developer ID release assets, TestFlight, notarization, unrelated capabilities, and product code.

## Acceptance Criteria
1. All four App IDs and shared groups exist under the expected Relux Works team and match the approved naming matrix exactly. 2. Host and provider capabilities are least-privilege and the packet-tunnel entitlement appears only on provider identifiers. 3. Development profiles are generated for the intended physical iPhone and Mac contexts and inspect to the expected team, application identifier, entitlements, devices, and validity. 4. Reproduction steps and privacy-safe profile metadata are attached as a TASK-ID-scoped outcome resource; raw profiles, certificates, and private keys are not attached or committed. 5. Any portal limitation or capability requiring Apple approval is recorded as an explicit external blocker rather than bypassed.
