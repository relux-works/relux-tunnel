# Select the project generator and deployment-target policy

## Description
Research and decide the supported project-generation tool and exact minimum iOS and macOS deployment targets for the new workspace. Start from the Relux Works Tuist convention, but record a different choice only when current support evidence makes it materially safer.

## Scope
In scope: current supported Tuist and viable alternatives; deterministic generation and pinning; Xcode and Swift toolchain support; Network Extension, Network.framework, Swift concurrency, selected dependency requirements, physical-device coverage, CI runner availability, and upgrade policy. Out of scope: installing tools globally, generating the project, lowering targets through private APIs or compatibility shims, and choosing SSH or relay implementations.

## Acceptance Criteria
1. A dated TASK-ID-scoped research artifact compares the supported generator choices against deterministic output, extension targets, signing configuration, dependency integration, CI maintenance, and Relux Works conventions. 2. The chosen tool and version or version range, pinning mechanism, bootstrap command, and upgrade owner are explicit. 3. Exact minimum iOS and macOS versions are selected from current API, dependency, device, Xcode, and CI evidence rather than preference. 4. The policy names the current physical iPhone and Apple-silicon Mac baseline plus the oldest versions that must build and test. 5. Any unsupported assumption becomes a blocking research item instead of a speculative configuration.
