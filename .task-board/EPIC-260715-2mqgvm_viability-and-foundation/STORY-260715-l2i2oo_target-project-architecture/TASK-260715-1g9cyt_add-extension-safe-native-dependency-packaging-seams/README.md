# Add extension-safe native dependency packaging seams

## Description
Implement the reproducible packaging and linkage mechanism that later HEV and SSH candidate tasks will use for C and Swift native dependencies in iOS and macOS provider targets and the macOS harness.

## Scope
In scope: source or static-library integration chosen by the ADR; module maps and headers; target triples and architectures; simulator and device variants; compile flags; extension-safe linkage checks; pinned revision inputs; license and notice aggregation hooks; dependency cache policy; a harmless smoke library fixture. Out of scope: integrating HEV, NIOSSH, or libssh2 themselves; dynamic downloads during application runtime; private frameworks; vendored unpinned binaries; and production transport code.

## Acceptance Criteria
1. A pinned harmless native fixture builds and links in iOS simulator, iOS device, macOS provider, shared-core consumer where allowed, and harness configurations. 2. Archive inspection shows no disallowed dynamic library, absolute build path, missing architecture, or extension-unsafe dependency. 3. Revision, source hash, compiler flags, license metadata, and rebuild commands are machine-readable inputs. 4. Dependency updates produce deterministic artifacts and a clear review diff rather than opaque binary replacement. 5. The seam documents how HEV and both SSH candidates plug in without forcing a target-graph redesign.
