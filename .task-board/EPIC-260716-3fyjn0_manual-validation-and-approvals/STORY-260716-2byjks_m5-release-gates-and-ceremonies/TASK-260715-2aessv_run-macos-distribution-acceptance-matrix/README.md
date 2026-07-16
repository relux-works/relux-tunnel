# Run the macOS signed-distribution acceptance matrix

## Description
Perform the independent end-to-end gate on the exact macOS release candidate, combining archive, entitlement, signature, notarization, publication, install, upgrade, VPN smoke, compliance, evidence, and rollback results.

## Scope
In scope: approved supported macOS versions on named Apple-silicon hardware, exact published digest, authenticated retrieval, code and entitlement inspection, Gatekeeper, notarization ticket, relay integrity, notices and SBOM access, clean install, upgrade, migration or coexistence, extension approval, connect and disconnect smoke, relaunch, uninstall, rollback rehearsal result, credential and secret audit, and pass or fail evidence index. Out of scope: implementing fixes, accepting skipped signing gates, exhaustive packet performance, iOS distribution, and human approval without recorded evidence.

## Acceptance Criteria
1. The verifier starts from the remote published asset, not a local build directory, and proves its digest, source, relay bundle, versions, signature chain, exact entitlements, notarization ticket, and evidence identity. 2. Every required clean-install, upgrade, system-approval, connect or disconnect, relaunch, uninstall, and rollback row passes on the declared supported Mac matrix or records a blocking failure. 3. SBOMs, notices, privacy and support resources, checksums, provenance, release notes, and authenticated download instructions are present and match the candidate. 4. Logs, artifacts, runner state, keychains, caches, and evidence contain no private signing or publication material. 5. A TASK-ID-scoped verdict lists each gate, environment, command, artifact digest, result, anomaly, residual risk, and blocker and is required before cross-platform release promotion.
