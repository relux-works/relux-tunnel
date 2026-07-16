# Implement the shell-safe relay path and command builder

## Description
Implement typed construction of the fixed remote bootstrap operations and private user-owned paths, quoting every dynamic token and rejecting unsafe directory, file, or command state rather than exposing a general shell API.

## Scope
In scope: approved fixed operations only; HOME cache candidate under .cache/relux-tunnel; safe user temporary fallback; random and versioned basename grammar; POSIX shell single-token quoting; umask 077; mkdir and permissions; regular-file, owner, symlink, and directory checks supported by fixtures; chmod, hash, rename, remove, and exec token plans; bounded output parser contracts; secret-exclusion tests. Out of scope: interactive shells, arbitrary commands, profile-provided install paths, environment-variable expansion from untrusted input, root or sudo, system directories, SFTP, and executing before verification.

## Acceptance Criteria
1. Callers choose only typed bootstrap operations and validated path components; no API accepts an arbitrary command string or unbounded remote output. 2. Every dynamic token round-trips as one shell argument across spaces, quotes, metacharacters, newlines, leading dashes, and Unicode policy cases or is rejected before channel open. 3. The cache path and temporary fallback are derived from fixed remote user context, created with private permissions, and rejected on unsafe owner, symlink, non-directory, traversal, control character, or length state. 4. Rendered commands never contain profile secrets, private-key material, passphrases, destination traffic, raw manifest content, or remotely returned diagnostic text. 5. Golden and hostile-input tests execute rendered plans in a controlled shell fixture and prove exact argv, no injected side effect, stable error mapping, and cleanup commands for every partial state.
