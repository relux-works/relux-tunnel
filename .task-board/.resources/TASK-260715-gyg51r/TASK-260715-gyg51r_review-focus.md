# Independent review focus

Review TASK-260715-gyg51r and Change Request CR-TASK-260715-gyg51r-1 revision 1 independently. Reproduce the bounded arm64 loopback matrix through ReluxTunnelHarness only; never start/install/sign NetworkExtension, create VPN preferences, or modify routes, DNS, interfaces, packet filters, Keychain, or external network state.

Required checks:

1. Inspect the implementation and ensure `mtu-matrix` is genuinely loopback-only, bounded in time/memory/packets, uses actual requested/effective Darwin socket buffers, separates sender refusal from receiver queue drops, and always closes owned descriptors. Reject fabricated counters or synthetic pass rows.
2. Independently rerun all 36 MTU/family/pressure rows and verify raw JSON schema, source/config/device metadata, row cardinality, hashes, nominal/mixed zero-loss, bounded named constrained/stalled outcomes, recovery, and zero owned-resource growth.
3. Challenge the 8500/4096 finding and the 1500...4096 plus 32768...262144 recommendation; ensure loopback throughput is not treated as external path-MTU/fragmentation proof and no final tuning is hardcoded.
4. Verify native IPv6 evidence, and honest unavailable/deferred handling for NAT64, energy, and iPhone.
5. Run focused/full tests, coverage, format, diff, privacy/safety scans, and board validation. Inspect the candidate patch completely.
6. Attach a distinct review outcome and issue one verdict. Accepted work may reach done only if all AC are independently evidenced; otherwise route exact rework.
