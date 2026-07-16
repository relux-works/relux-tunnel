# Implement private atomic relay install, reuse, and upgrade

## Description
Install only verified relay bytes into the user-owned versioned location with mode 0700, atomic publication, safe reuse, concurrent-attempt coordination, stale temporary cleanup, and explicit read-only or noexec failure.

## Scope
In scope: version and hash-derived final basename; parent directory validation; regular-file and owner checks; chmod 0700 after verification; same-filesystem atomic rename; existing matching-file reuse after reverification; mismatch quarantine or replacement policy; concurrent identical and competing installs; stale random-file cleanup; read-only and noexec detection; cancellation before publication; bounded diagnostics. Out of scope: root installation, service registration, PATH changes, global locks, deleting unrelated user files, remote cache eviction policy beyond Relux-owned names, launching the session, SFTP, and self-update outside app-selected assets.

## Acceptance Criteria
1. Only a temporary file that passed exact size and SHA-256 verification is chmodded and atomically renamed into a validated Relux-owned versioned regular-file path. 2. Existing assets are reused only after owner, type, mode, size, and checksum validation; a known mismatch is never executed or silently accepted. 3. Concurrent bootstrap attempts converge on one valid final file or a stable typed conflict without partial publication, unrelated deletion, symlink following, or cross-device non-atomic rename. 4. Read-only home, unsafe cache, unavailable safe temporary directory, noexec, chmod or rename failure, cancellation, and SSH loss leave no published invalid asset and map to specific capability reasons. 5. Controlled-host tests cover first install, reuse, upgrade, competing versions, symlink attacks, stale files, permission failures, noexec, interruption at every operation, and Relux-owned cleanup only.
