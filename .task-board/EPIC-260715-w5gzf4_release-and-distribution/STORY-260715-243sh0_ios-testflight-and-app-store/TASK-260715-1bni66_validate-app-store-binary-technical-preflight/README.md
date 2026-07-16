# Validate the exact App Store binary technical preflight

## Description
Run Apple server and local binary preflight checks on the same processed candidate intended for App Review and prove no rebuild, entitlement change, or profile change occurs after TestFlight acceptance.

## Scope
In scope: exact App Store Connect build ID, local archive or export digest, validation transport, bundle and app-record mapping, versions, profiles and entitlements, architecture, privacy manifests, required-reason APIs, symbols, encryption inventory, prohibited content or private APIs, server warnings, build selection lock, and evidence handoff to the review package. Out of scope: final privacy or export declarations, age rating, content rights, public metadata, screenshots, support and privacy URLs, storefront approval, App Review submission, and dismissing Apple warnings without an owned disposition.

## Acceptance Criteria
1. The selected App Store Connect build is the exact digest, marketing version, build number, source, signing identity, profiles, relay manifest, and protocol version accepted by the TestFlight matrix. 2. Local and App Store Connect binary validation pass for bundle topology, entitlements, architectures, privacy manifests, required-reason APIs, symbols, encryption inventory, versioning, and prohibited private APIs. 3. The build selection is locked by App Store Connect ID and evidence revision and no rebuild, resign, profile substitution, or resource change can inherit the preflight. 4. Every server warning has an accountable technical accept or block disposition linked to evidence and a later warning or binary state change invalidates the preflight. 5. Wrong build selection, rebuild, profile drift, missing symbol, manifest mismatch, changed encryption inventory, validation outage, or new warning blocks handoff to the submission package.
