# Verify macOS bundle topology, profiles, and entitlements

## Description
Implement automated pre-sign and post-sign inspection that proves the macOS host and tunnel extension have the exact identities, containment, profiles, entitlements, and restricted-resource boundaries declared by the release contract.

## Scope
In scope: bundle traversal, Info.plist, code-signing identifiers, Team ID, embedded profiles where required, application identifier, packet-tunnel entitlement, App Groups, Keychain groups, sandbox or hardened-runtime-related rights as approved, extension point, host relationship, designated requirements, version fields, unexpected entitlement denial, and machine-readable diff. Out of scope: performing signatures, notarization, functional VPN testing, broadening profiles, and accepting Xcode defaults without inspection.

## Acceptance Criteria
1. The verifier enumerates every signable nested path and compares its identifier, Team ID, profile class and expiry, entitlements, version, extension point, and containment to the approved matrix. 2. Host and extension entitlement sets are compared separately and extra, missing, wildcard, development-only, debugger, library-validation, network, file, or keychain rights fail unless explicitly approved. 3. Pre-sign checks validate build inputs and post-sign checks extract actual signed entitlements and designated requirements from the archived candidate. 4. Results are deterministic, machine-readable, redacted, and included in release evidence with public certificate and profile metadata only. 5. Golden and negative fixtures cover wrong team, swapped profile, wildcard ID, host-extension mismatch, extra entitlement, missing App Group or Keychain group, expired profile, wrong version, and unexpected nested code.
