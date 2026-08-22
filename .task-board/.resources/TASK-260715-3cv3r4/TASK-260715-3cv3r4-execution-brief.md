# TASK-260715-3cv3r4 execution brief

Implement the accepted task exactly against the current repository state.

Safety and scope boundaries:

- Use deterministic fakes only. Do not read, write, enumerate, unlock, or prompt the real macOS Keychain.
- Do not open a real SSH connection, contact external hosts, launch/install/sign a NetworkExtension provider, create or start a VPN configuration, or mutate routes, DNS, interfaces, or packet-filter state.
- Fixture secrets, hostnames, addresses, keys, and passphrases must be synthetic and must be covered by prohibited-data/redaction assertions.
- Exercise behavior through the existing SPM harness and focused Swift tests. Preserve the candidate-neutral SSH boundary and host-key verification-before-auth invariant.
- Repeated cleanup checks must use deterministic, bounded repetitions and prove no retained secret container, task, connection, observer, or callback growth.
- Attach a task-scoped outcome with the exact test matrix, commands, results, and any residual risk. Handoff only after every acceptance criterion and checklist item is evidenced.

Do not broaden this task into UI, physical-device, real-network, performance, route-setting, password-authentication, or production-credential work.
