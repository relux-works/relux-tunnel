# Inspect iOS profiles, entitlements, bundle topology, and architectures

## Description
Automate independent inspection of the signed archive and exported application so actual host and extension identities, profiles, entitlements, versions, architectures, resources, and designated relationships match the approved distribution contract.

## Scope
In scope: archive and IPA traversal, Info.plists, bundle IDs, Team ID, application identifiers, embedded mobileprovision files, distribution class and expiry, packet-tunnel entitlement, App Groups, Keychain groups, get-task-allow, beta reports active where applicable, extension point, host containment, code signatures, architecture slices, deployment target, versions, relay hashes, unexpected nested code, and deterministic report. Out of scope: creating signatures, modifying profiles, functional VPN testing, App Store server validation, and treating development provisioning as a release substitute.

## Acceptance Criteria
1. The verifier enumerates every signed bundle and executable and compares identifiers, Team ID, distribution profiles and expiry, entitlements, extension point, containment, versions, architectures, and deployment targets to the approved matrix. 2. get-task-allow, wildcard identifiers, development profiles, extra App Groups or Keychain groups, unrelated capabilities, missing packet-tunnel rights, and host-extension mismatches fail. 3. Relay resources, privacy manifests, notices, symbols inventory, and unexpected nested frameworks or executables are checked by digest and policy. 4. Results are machine-readable, redacted, reproducible, and retained with public certificate and profile metadata but no private key or issuer material. 5. Negative fixtures cover swapped or expired profile, wrong team, extra entitlement, missing group, wrong extension point, version mismatch, unsupported architecture, tampered resource, and undeclared code.
