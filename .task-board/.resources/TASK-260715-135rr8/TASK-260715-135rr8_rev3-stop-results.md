# TASK-260715-135rr8 rev3 stop outcome

## Result

Rev3 implemented the two requested fail-closed gates, but the corrected lifecycle gate exposed reproducible post-warmup physical-footprint growth. The task remains in development and is not ready for review.

## Candidate and integration scope

- Candidate working tree: `7938b745f4dd2f79bfeca15e2f262fcade04327c`
- Current main checked: `d177ac7dae6c10b7527c15f0a1ad31387890828e`
- Repository delta: exactly `LOGBOOK.md`, `README.md`, and `Tests/ReluxTunnelNativeAdapterTests/HEVBridgeIntegrationTests.swift`
- Final three-file patch SHA-256: `f2aa59d822772fbc2cf30217301fc7c79aa5be73e286fae800becef4258ca4a4`
- `git apply --check` against a detached current-main worktree: exit 0
- No MTU files are present in the patch.

## Implemented rev3 gates

- The opt-in matrix production entry independently resolves the actual working candidate tree with `git read-tree`, `git add -A`, and `git write-tree` through a task-local temporary index. It rejects a well-formed supplied mismatch before HEV startup or evidence emission.
- The entry independently hashes the linked macOS `libhev-socks5-tunnel.a` and compares it with the pinned manifest lock.
- Lifecycle analysis excludes a fixed 10-sample allocator warmup and records analyzed count, net change, and increase/equal/decrease transitions. A non-decreasing analyzed window with at least one increase throws before matrix flow staging.
- Negative tests cover a forged 40-hex candidate OID, a forged HEV artifact hash, rise-plus-plateau growth, and stabilized-after-warmup plateau.

## Gate results

- Focused provenance negative test: exit 0.
- Focused lifecycle-classifier tests: exit 0.
- Strict recursive Swift format lint: exit 0.
- `git diff --check`: exit 0.
- Narrow privacy/safety scan: exit 0.
- Direct 100-cycle lifecycle probes: exit 1 on all three runs.
  - Probe 1: `+81,920 B`, transitions `4/85/0` increase/equal/decrease.
  - Probe 2: `+81,920 B`, transitions `5/84/0`.
  - Probe 3: `+98,328 B`, transitions `4/85/0`.
- Exact-tree opt-in production entry: exit 1 at lifecycle prerequisite with `+163,840 B`, transitions `7/82/0`; no matrix JSON was emitted and no 100/250/500 flow row was staged.

## Stop reason and deferred gates

The rev3 instruction explicitly requires stopping with evidence when post-warmup measurements genuinely remain monotonic non-decreasing. Four bounded runs reproduced the signal, including an exact-tree opt-in production invocation. The rule was not weakened. Three successful matrix runs, full Swift suite, affected coverage, CR rev3 publication, and tester handoff were therefore not performed. Their gates remain failing or unverified for this revision.

No NetworkExtension or VPN was installed or started. No route, DNS, interface, packet-filter, SSH, Keychain, global memory-pressure, `sudo`, `powermetrics`, `memory_pressure`, `launchctl`, or unrelated-process mutation was performed.
