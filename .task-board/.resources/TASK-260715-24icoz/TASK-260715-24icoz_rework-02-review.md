# TASK-260715-24icoz rework-02 review contract

Review only the safe temporary archive replacement rework and regressions, while confirming the previously accepted relay-asset evidence remains intact.

Required independent checks:

1. Reproduce the former predictable sibling-temp symlink attack. Confirm the planted symlink is neither followed, replaced, nor unlinked and its victim bytes remain unchanged.
2. Confirm the implementation creates an exclusive random temporary regular file in the archive destination directory and retains an owned file descriptor/inode identity for cleanup.
3. Confirm cleanup removes only the temporary file created by this invocation, including an injected `os.replace` failure; it must not remove a path replaced by another actor.
4. Confirm the final archive is a regular non-symlink file and pre-existing symlink destinations are rejected without mutating their targets.
5. Confirm the deterministic archive contract remains exact: four canonical members only, USTAR+gzip, fixed integer mtime, root ownership metadata, mode 0755, no PAX/xattrs/AppleDouble members, stable SHA-256.
6. Run the focused release tests, Go tests/vet, lint/privacy checks, native Darwin arm64 and approved Rosetta amd64 rootless smokes. Do not claim Linux/native-Intel execution; those remain deferred.
7. Inspect the diff for unrelated changes, sensitive paths/data, and build-host-policy violations.

Build-host safety is mandatory: do not sign, install, approve, configure, or launch a VPN app/provider; do not call `startVPNTunnel`; do not modify system VPN preferences, routes, or DNS. Rootless relay binaries and harness tests are allowed.

Return an explicit accepted or changes-requested verdict with task-scoped evidence. Never stop at reviewing.
