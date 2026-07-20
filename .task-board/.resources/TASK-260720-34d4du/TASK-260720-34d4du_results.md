# TASK-260720-34d4du implementation results

Implemented three public adapter-conformance seams in ReluxNIOSSH: future-based external public-key signing over the exact RFC 4252 payload with no NIOSSHPrivateKey; bounded want-reply generic global requests using the protected ordered packet path; and client KEX/host-key allowlists plus an immutable exact negotiated-algorithm snapshot.

The audited allowlist grows from 16 to 20 files: four newly patched upstream paths and no new fork-only files. No upstream crypto or algorithm implementation changed.

Verification passed: focused 3-test adapter-conformance suite; full 323 upstream XCTest suite; all 13 fork Swift Testing cases; make validate-reluxniossh; strict swift format lint; make validate-core with 61 root tests and build. Unified diff SHA-256: b162e69a1b81951f9738b4198ffc75ccbb95dcc9a68cee16ff889f346888cf5c.