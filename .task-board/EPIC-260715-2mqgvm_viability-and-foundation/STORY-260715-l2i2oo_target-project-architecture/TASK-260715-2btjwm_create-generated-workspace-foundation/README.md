# Create the reproducibly generated workspace foundation

## Description
Implement the chosen project-generator configuration, shared build settings, configurations, schemes, and version inputs that form the empty multi-target workspace. This task establishes deterministic structure only; platform products are added by dependent tasks.

## Scope
In scope: pinned generator bootstrap; workspace and project definitions; Debug and Release settings; bundle-version inputs; Swift settings; generated-file policy; scheme conventions; credential-free signing placeholders; deterministic clean generation; source-controlled configuration. Out of scope: host or provider source, shared core APIs, native dependencies, relay implementation, release credentials, and deleting Package.swift.

## Acceptance Criteria
1. The pinned bootstrap command generates the same workspace, project names, configurations, and shared settings from a clean checkout without manual Xcode edits. 2. Generated artifacts follow the ADR source-control policy and a second generation produces no unexplained diff. 3. Debug and Release versions, bundle settings, deployment targets, and credential-free signing behavior come from documented inputs. 4. Schemes have stable names suitable for local and CI invocation. 5. The existing SwiftPM package remains present and its files are not silently absorbed or removed.
