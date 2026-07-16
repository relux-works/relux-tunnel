# Record the iOS distribution, signing, version, and TestFlight contract

## Description
Create the binding iOS delivery contract for ReluxProxyIOS, its packet-tunnel extension, Apple Distribution identities and profiles, App Store Connect roles, versions, archive and export method, TestFlight groups, embedded relay and compliance resources, and rollback semantics.

## Scope
In scope: Gate A0 and P0 constraints, host and extension bundle IDs and containment, Team ID, App Group and Keychain groups, packet-tunnel entitlement, distribution profiles, certificate class, archive and export settings, marketing and build versions, relay manifest and resources, privacy manifest, symbols, TestFlight internal and approved external groups, processing and expiry, App Store binary identity, evidence, withdrawal, supersession, and credential ownership. Out of scope: issuing credentials, public metadata copy, regional legal decisions, Developer ID or notarization, product feature implementation, and adding capabilities to force an invalid archive.

## Acceptance Criteria
1. A TASK-ID-scoped matrix lists every bundle path, identifier, profile, entitlement, version, architecture, resource, signing input, export setting, App Store Connect role, TestFlight group, and verification command. 2. Host and extension use matching approved distribution identities and only the minimum packet-tunnel, App Group, Keychain, and related capabilities traced to Gate P0. 3. Marketing version, monotonic build number, relay protocol and build identity, archive, export, TestFlight build, and later App Review binary are one traceable candidate with no rebuild between channels. 4. Signed-output nondeterminism is distinguished from reproducible source, dependency, generated-project, unsigned-payload, and resource inputs. 5. Platform, security, release, product, and App Store owners approve the contract or disputed signing, group, version, or channel choices remain explicit blockers.
