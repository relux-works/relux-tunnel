# Create versioned and stable-name macOS DMG artifacts

## Description
Package the signed and verified application into the declared DMG layout, emit immutable versioned and stable-name files from the same bytes, and generate checksums before publication.

## Scope
In scope: signed application input by digest, DMG filesystem and compression policy, volume name, application presentation and Applications link if approved, license or readme resources, safe file names, versioned artifact, stable ReluxProxy.dmg alias or byte-identical copy, deterministic pre-sign layout where possible, DMG signature if required by contract, SHA-256 files, size checks, mount and copy smoke, and cleanup. Out of scope: notarization submission, GitHub upload, changing user interface, embedding a different application per name, and presenting stable and versioned files from different builds.

## Acceptance Criteria
1. Packaging consumes the exact signed application digest and creates the approved volume layout with no extra executables, secrets, quarantine-clearing scripts, or undeclared writable content. 2. The immutable versioned DMG and stable ReluxProxy.dmg represent exactly the same candidate bytes or one documented canonical file plus alias semantics verified by digest. 3. File names, volume name, displayed version, application identity, permissions, compression, size, and optional DMG signature match the release contract. 4. Fresh mount, application copy, read-only verification, unmount, checksum recomputation, and repeated cleanup succeed on a clean supported Mac. 5. Wrong input digest, mixed versions, stale mounted image, extra file, unsafe path, oversize artifact, checksum mismatch, mount failure, or byte divergence between stable and versioned assets blocks publication.
