# Validate semantic versions, tags, bundle versions, and release notes

## Description
Implement a single source-of-truth gate for marketing version, protocol version, platform build numbers, Git tags, artifact names, changelog content, and migration or compatibility release notes.

## Scope
In scope: semantic tag format, monotonic version rules, iOS build numbers, macOS bundle versions, relay protocol and build identity compatibility, generated workspace inputs, artifact naming, stable versus versioned assets, release-note sections, breaking or migration disclosures, and dry-run validation. Out of scope: choosing product launch timing, allocating App Store Connect numbers, publishing releases, and writing marketing copy beyond required technical sections.

## Acceptance Criteria
1. One deterministic command derives or validates the intended marketing version, platform bundle versions, relay protocol compatibility, Git tag, and artifact names from approved inputs. 2. Mismatched, nonmonotonic, dirty-tree, duplicate, malformed, or unsupported compatibility versions fail before credentialed jobs start. 3. Release notes identify source range, user-visible changes, security or privacy changes, migration impact, compatibility, known limitations, rollback reference, and exact candidate artifacts. 4. The gate verifies stable names are aliases to a versioned immutable release rather than independent untraceable builds. 5. Unit or fixture tests cover prerelease, patch, protocol-compatible, protocol-breaking, rollback, missing-note, and duplicate-build cases.
