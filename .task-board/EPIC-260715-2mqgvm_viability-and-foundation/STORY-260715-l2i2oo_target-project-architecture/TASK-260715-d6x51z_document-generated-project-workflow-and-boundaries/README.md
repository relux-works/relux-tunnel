# Document the generated-project workflow and migration boundaries

## Description
Publish developer-facing documentation for bootstrapping, generating, building, testing, signing inputs, target ownership, artifact locations, dependency updates, harness use, relay cross-builds, and coexistence with the legacy SwiftPM product.

## Scope
In scope: exact prerequisites and commands; pinned tools; generated versus edited files; schemes and targets; credential-free versus Gate P0 signing paths; test and log locations; native dependency update process; troubleshooting; architecture links; migration non-goals. Out of scope: product user documentation, release operations beyond links to existing behavior, packet or SSH usage, and undocumented local setup.

## Acceptance Criteria
1. Documentation lets a developer start from a clean checkout and reproduce generation, all credential-free builds, shared tests, harness smoke, relay smoke, and legacy validation using exact commands. 2. A target-ownership table names the source, tests, responsible module, allowed dependencies, and applicable specifications for every target. 3. Signing documentation references Gate P0 non-secret identifiers and explains where local credentials come from without instructing users to commit them. 4. Generated-file rules, dependency-update steps, artifact locations, and common failures are explicit. 5. Documentation is checked against the clean verification evidence and contains no claim that packet, SSH, relay, or distribution features already exist.
