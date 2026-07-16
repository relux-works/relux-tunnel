# Record and publish the Gate P0 disposition

## Description
Consolidate account, identifier, profile, archive-inspection, iPhone, and Mac evidence into the authoritative Gate P0 decision. This record controls whether later Apple-target packet and SSH integration may rely on physical-device capability viability.

## Scope
In scope: evidence index; exact pass and fail criteria; identity and entitlement matrix revision; device and OS coverage; known manual approvals; reproducibility; expiry and revalidation triggers; downstream dependencies; accountable owner acknowledgement. Out of scope: asserting Gate A0, packet bridge or SSH matrix results; release distribution; storing signing secrets; and accepting a simulator or single-platform result.

## Acceptance Criteria
1. A TASK-ID-scoped Gate P0 report links the readiness audit, approved identity matrix, portal metadata, archive inspections, and both physical-device result bundles. 2. Pass requires successful provider install, launch, versioned app message, and stop on both the named physical iPhone and physical Apple-silicon Mac with matching entitlements and profiles. 3. Any missing platform, entitlement mismatch, unexplained lifecycle failure, expired profile, or unresolved portal approval produces fail or blocked rather than conditional pass. 4. The record states profile and agreement expiry, device or OS changes, and capability edits that require revalidation. 5. The accountable engineering or release owner acknowledges the verdict and the downstream tasks it unblocks or leaves blocked.
