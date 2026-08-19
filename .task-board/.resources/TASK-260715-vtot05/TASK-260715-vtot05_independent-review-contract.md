# Independent review contract for TASK-260715-vtot05

Review the producer's complete uncommitted diff independently against every task AC and checklist item. Do not accept the producer handoff as proof.

## Load-bearing checks

- Reconstruct the accepted relay-byte provenance from immutable commits/trees/files and the accepted four-asset archive. Verify that every byte-affecting source, build recipe, compiler/linker input, standard-library dependency, license, and notice obligation is covered and accurately classified.
- Verify source URLs and identifiers are immutable and that generated metadata contains no credentials, tokens, local usernames, workstation/temp paths, or mutable `latest`-style references.
- Verify the checked-in inventory, provenance, product notices, license payloads, asset source contract, generated manifest, schema, and Swift catalog share a deterministic, non-circular linkage and fail closed on drift.
- Verify missing metadata, missing notice coverage, mutable sources, manifest-linkage drift, and runtime executable-code download surfaces are rejected by meaningful negative tests. Inspect the runtime scan scope for omissions and false claims.
- Verify the M2/M5 boundary maps signing, notarization, attestation, and distribution approval to the concrete downstream tasks without performing those actions.
- Inspect CI/Makefile integration and run the focused audit/test/build gates. Confirm generation is byte-deterministic.
- Treat the current `PARENT_STATUS_MISMATCH` board validation result separately: determine whether it is a pre-existing aggregate-status constraint or evidence that this task's handoff is invalid. Do not weaken validation.

## Build-host safety

This is a build-only Mac. Do not sign/install/launch the app or provider, mutate VPN preferences, call `startVPNTunnel`, alter routes/interfaces/pf/DNS, or run real/physical VPN validation. Do not inspect Keychain or notarization/signing credentials. Repository reads, deterministic generation, unsigned builds, tests, and rootless non-network fixtures are allowed.

If any material finding exists, return the task to `to-dev` with exact evidence and a focused remediation contract. Accept only when independent evidence proves all ACs and no required work remains.
