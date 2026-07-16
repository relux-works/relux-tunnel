# Produce relay provenance attestations and the release staging bundle

## Description
Assemble immutable relay assets, manifests, checksums, SBOMs, notices, scan results, conformance evidence, and provenance attestations into the exact input bundle consumed by Apple release workflows.

## Scope
In scope: staging directory or archive layout, artifact digests, SLSA-compatible or approved provenance predicate, builder and invocation identity, input materials, reproducibility evidence, manifest and SBOM digests, notices, scan summaries, test evidence, attestation signing through approved keyless or protected mechanism, access control, retention, and downstream verification. Out of scope: Apple code signing, public release publication, embedding production credentials, and rebuilding relay bytes during Apple workflows.

## Acceptance Criteria
1. Staging contains exactly the four verified assets plus canonical manifest, checksums, SBOM, notices, scan and test summaries, reproducibility record, and provenance attestations with deterministic names. 2. Each attestation binds builder, invocation, immutable source and dependency materials, toolchains, subject digests, and relevant evidence without private secret values. 3. Downstream verification starts from a trusted attestation root or approved identity, checks every digest and schema, and rejects missing, extra, replaced, or untrusted content. 4. The Apple release workflows consume staged bytes by digest and cannot rebuild, fetch, or silently substitute relay assets after verification. 5. Tamper, omitted-file, wrong-subject, untrusted-signer, stale-evidence, and retention or access-control fixtures fail staging.
