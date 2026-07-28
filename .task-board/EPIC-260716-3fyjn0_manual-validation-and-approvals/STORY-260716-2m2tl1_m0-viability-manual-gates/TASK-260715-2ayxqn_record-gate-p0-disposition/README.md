# Record the macOS Gate P0 disposition

## Description
Record the Gate P0 provisioning disposition for the macOS-only prototype target from the physical Apple-silicon Mac evidence. Physical P0 for this goal is macOS-only on the current arm64 Mac; the physical-iPhone row is deferred with iOS and must not gate this disposition.

## Scope
In scope: macOS host and packet-tunnel identifier install and launch evidence on the physical Apple-silicon Mac; entitlement and profile presence; system-VPN approval outcome; blockers and residual risks; the tasks unblocked for the macOS prototype path. Out of scope: physical-iPhone rows and any iOS disposition (deferred), App Review or Gate A0 conclusions, and accepting P0 without real device evidence.

## Acceptance Criteria
1. A TASK-ID-scoped Gate P0 report links the readiness audit, approved identity matrix, portal metadata, archive inspections, and the physical Apple-silicon Mac result bundle; the physical-iPhone bundle is a named deferred gap under ADR-024. 2. Pass requires successful provider install, launch, versioned app message, and stop on the named physical Apple-silicon Mac with matching entitlements and profiles; the physical-iPhone row is recorded as deferred with iOS and is never inferred from Mac results. 3. Any missing in-scope macOS evidence, entitlement mismatch, unexplained lifecycle failure, expired profile, or unresolved portal approval produces fail or blocked rather than conditional pass. 4. The record states profile and agreement expiry, device or OS changes, and capability edits that require revalidation. 5. The accountable engineering or release owner acknowledges the verdict and the downstream tasks it unblocks or leaves blocked.
