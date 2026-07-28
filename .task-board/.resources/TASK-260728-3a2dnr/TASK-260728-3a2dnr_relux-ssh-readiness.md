# Relux SSH host readiness — 2026-07-28

The primary orchestrator executed a read-only BatchMode probe against the owner-authorized SSH alias `relux`. Authentication succeeded without a prompt. The remote reports Darwin on x86_64. No hostname, IP address, username, key path, credential, environment value, or remote file content was recorded.

Planning consequence: access required by TASK-260715-39xz9g is available in this primary environment and is not an unevidenced human hold. The task must still perform host-key verification and its own fixture validation; this readiness probe is not conformance evidence.