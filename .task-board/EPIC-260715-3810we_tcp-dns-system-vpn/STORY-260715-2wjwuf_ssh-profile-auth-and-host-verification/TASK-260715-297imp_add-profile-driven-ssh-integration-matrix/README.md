# Run the profile-driven SSH authentication integration matrix

## Description
Exercise the production profile loader, approved-host policy, Keychain test references, bootstrap service, and M0-selected SSH adapter together against controlled OpenSSH fixtures. Validate production ordering and error behavior without repeating the engine-selection conformance matrix.

## Scope
In scope: current supported Linux and macOS OpenSSH fixtures, canonical hostname and literal endpoints, Ed25519 and approved fallback user keys, approved and changed host keys, auth rejection, passphrase-protected test key if supported, IPv4 and IPv6 actual endpoint capture, cancellation at each stage, repeated sessions, and resource counts. Out of scope: comparing SSH engines, rekey scale testing, hundreds of direct channels, relay exec, production credentials, path migration, ProxyJump, and physical Network Extension behavior.

## Acceptance Criteria
1. A TASK-ID-scoped matrix records fixture versions, algorithms, public fingerprints, source and dependency revisions, profile generation, endpoint family, commands, duration, and pass or fail by row. 2. Successful rows prove profile load, exact test credential reference, pre-auth host approval, public-key auth, actual endpoint capture, metrics, and clean close. 3. First use, changed host key, wrong account or key, inaccessible reference, unsupported algorithm, timeout, and cancellation fail at the expected stage with no later credential or auth action where prohibited. 4. At least one hundred sequential bootstrap and close cycles show no monotonic socket, task, session, Keychain-object, or secret-container growth. 5. Results reference the selected M0 adapter and fixture artifacts rather than rerunning or weakening the M0 engine gates.
