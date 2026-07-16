# Assemble and export the iOS App Store archive

## Description
Build the approved iOS Release scheme, embed the packet-tunnel extension and verified relay or compliance resources, archive with distribution settings, and export the exact candidate intended for TestFlight and App Review.

## Scope
In scope: clean generated workspace, ReluxProxyIOS host, one embedded ReluxProxyIOSTunnel, approved device architectures, deployment target, versions, Info.plists, relay manifest and staged assets required by policy, SBOM and notice resources, privacy manifest, symbols, distribution signing inputs, archive and export options, unsigned input hashes, archive inventory, export output, and cleanup. Out of scope: TestFlight upload, App Store metadata, product changes, rebuilding relay assets, simulator-only archives, and changing versions after signing.

## Acceptance Criteria
1. A clean protected build emits one xcarchive containing the approved host, exactly one embedded packet-tunnel extension, required resources and symbols, and no undeclared executable, framework, or capability. 2. Host and extension bundle IDs, Team ID inputs, deployment target, architectures, marketing and build versions, extension point, and containment match the release contract. 3. Relay and compliance resources are copied by digest from approved staging and reverified in the archive before export. 4. Export uses the declared App Store distribution method and records archive and exported artifact hashes, source, locks, generator, Xcode, SDK, versions, and signing metadata without secrets. 5. Missing or duplicate extension, wrong architecture, stale relay, version drift, dirty generation, missing privacy or notice resource, profile mismatch, export warning treated as blocking, or undeclared nested code fails.
