# Provision reproducible SSH matrix fixtures

## Description
Create the controlled server, key, algorithm, traffic, and network-condition fixtures required to run identical M0 matrices against both candidates, including the real relux server without exposing production credentials.

## Scope
In scope: current OpenSSH Linux and macOS endpoints; documented approved older algorithm profile; Ed25519 host and user keys; approved fallback host and user key types; host-key change fixture; direct-tcpip destinations; long-lived stdio exec echo or sink; at least 5 GiB deterministic traffic; latency and loss controls; early close and reset endpoints; real relux test host access; credential rotation and cleanup. Out of scope: production user data, broad Internet exposure, password or interactive auth, persistent root service, relay implementation, and storing private test credentials in git or board resources.

## Acceptance Criteria
1. A TASK-ID-scoped fixture manifest records server OS and OpenSSH versions, configurations, algorithms, host-key fingerprints, user-key types, destination services, traffic seeds, network profiles, and reproduction or teardown steps. 2. Current Linux, current macOS, one approved older compatibility profile, and the real relux host are reachable through least-privilege test identities. 3. Fixtures deterministically produce success, host-key first use, host-key change, auth rejection, channel rejection, early close, half-close, reset, server rekey, latency, loss, and disconnect conditions. 4. A 5 GiB or larger reproducible source and sink verifies byte counts and content hashes without retaining payload. 5. Secrets remain in an approved external store; artifacts contain only public keys, fingerprints, non-secret configuration, and secret-reference names.
