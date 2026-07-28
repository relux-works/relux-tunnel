# M5 — Release and distribution

## Description
Deliver tested macOS release pipelines, relay supply-chain controls, and compliance evidence. The iOS release pipeline and the App Review materials stay defined but are deferred with iOS and the App Store branch (ADR-013/ADR-024) and re-arm unchanged.

## Scope
Cross-platform CI, relay supply chain, macOS Developer ID/notarization, iOS signing/TestFlight (deferred with iOS, ADR-024), SBOM/notices, stable artifacts, release operations, privacy/legal, and App Review submission (deferred with the App Store branch, ADR-013).

## Acceptance Criteria
Signed release candidates install through intended channels; entitlement/signature/notarization gates pass, with the TestFlight gate deferred with iOS (ADR-024); relay assets are reproducible and verified; review/privacy/legal packages match actual behavior.
