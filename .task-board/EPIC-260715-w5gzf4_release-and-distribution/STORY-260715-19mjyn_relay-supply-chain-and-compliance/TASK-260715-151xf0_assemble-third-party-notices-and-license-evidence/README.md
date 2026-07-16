# Assemble third-party notices and license evidence

## Description
Create the human-readable notice bundle and machine-checkable mapping for HEV, hev-task-system, hev-socks5-core, lwIP, the selected SSH engine, relay dependencies, and every other shipped third-party component.

## Scope
In scope: exact locked revisions, canonical project names and source URLs, copyright and license texts, attribution requirements, binary-distribution obligations, modifications or fork disclosure where required, notice ordering, SBOM mapping, Apple bundle and DMG inclusion locations, source-offer obligations if discovered, legal review ownership, and completeness tests. Out of scope: inventing license interpretations, omitting transitive code, copying unrelated development-only dependencies, and modifying upstream licenses.

## Acceptance Criteria
1. Every shipped third-party component in the SBOM maps to exactly one reviewed notice entry and complete license text or an explicitly approved aggregation. 2. HEV, hev-task-system, hev-socks5-core, lwIP, the selected SSH engine, relay dependencies, forks, and modified components identify exact source revision and required attribution. 3. Notices are included in the declared application, DMG, support, or documentation locations and remain readable offline after installation. 4. Missing, stale, duplicated-conflicting, unknown-license, unreviewed-fork, or SBOM-unmapped components fail the compliance gate. 5. A dated legal or compliance review records findings, decisions, obligations, locations, and update triggers without treating automation as legal advice.
