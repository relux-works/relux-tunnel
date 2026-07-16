# Add the remote bootstrap failure, upgrade, and cleanup matrix

## Description
Exercise the integrated bootstrap and session startup against controlled Linux and macOS SSH fixtures representing both architectures and every declared install, verification, launch, and process failure.

## Scope
In scope: four declared target assets; current OpenSSH Linux and macOS fixtures; first install; verified reuse; same-version race; version upgrade; concurrent different versions; interrupted upload; disk-full; checksum mismatch; missing sha256sum or shasum; bounded readback fallback; read-only home; safe temporary fallback; no safe directory; noexec; permission and rename failure; incompatible protocol; stderr contamination; process exit; repeated cleanup. Out of scope: public unmanaged hosts, SFTP, root fixes, application UDP traffic, path transitions, final app signing, production credentials, and treating emulation as sufficient where native execution is required.

## Acceptance Criteria
1. Evidence records fixture OS, architecture, OpenSSH, shell, filesystem mode, asset identity, source revisions, commands, duration, result, reason code, and post-run owned-file and process state. 2. Successful rows prove first install, reuse without reupload, atomic upgrade, and safe concurrent convergence for every declared target combination available to CI or named external fixtures. 3. Every specified upload, hash, filesystem, launch, protocol, stderr, process, timeout, and cancellation failure produces the expected capability reason and never executes mismatched or partial bytes. 4. At least one hundred repeated mixed success and failure cycles show no monotonic task, channel, process, timer, buffer, or Relux-owned temporary-file growth. 5. A TASK-ID-scoped redacted result bundle and runbook let another authorized operator reproduce each row without receiving private credentials or real traffic data.
