# TASK-260715-1ue4oy independent reviewer results

Date: 2026-08-19
Role: reviewer
Verdict: changes requested
Route: to-dev

## Blocking findings

1. Bundle validation is not bounded before allocation. scripts/relay_asset_manifest.py read_regular_file performs path.read_bytes without an expected-size or maximum-size gate, and validate_bundle uses it for both the manifest and all four executables. A tampered sparse or oversized file can therefore force allocation proportional to attacker-controlled file size before the mismatch is rejected. The same lstat then reopen sequence is TOCTOU-prone. Fix with descriptor-owned O_NOFOLLOW reads, fstat size checks before reading, a hard manifest byte cap, exact asset size checks before content reads, and bounded or streaming digest and identity validation. Add oversized and symlink replacement regressions.

2. Generation publishes directly into the final bundle directory. generate_bundle creates the final directory and writes assets one by one; KeyboardInterrupt, process termination, or host failure can leave a partial trusted-path residue. A later generate sees the existing invalid directory and fails instead of recovering. Use an exclusive randomized sibling staging directory with ownership-aware cleanup and atomic publication or replacement, then add injected-failure and stale-replacement tests.

3. The modified provider validator is not lint-clean. black --check scripts/relay_asset_manifest.py scripts/tests/test_relay_asset_manifest.py scripts/check-generated-provider-graph.py exited 1 and reported scripts/check-generated-provider-graph.py would be reformatted. The producer lint evidence covered only two Python files.

4. The negative suite does not exercise the reviewer-contract unsafe path and symlink cases or the unbounded bundle-input cases above. Existing exact-name checks make traversal names fail and the implementation intends to reject symlinks, but those load-bearing paths require explicit regressions.

## Independently reproduced passes

- Accepted archive SHA-256: 1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e.
- Exact four ordered archive members independently streamed to sizes 2623664, 2487362, 2592894, 2556030 and SHA-256 values 783b9498..., 8ac45b25..., ddcb22ed..., 908b3d9e....
- Darwin arm64 and Rosetta amd64 identity commands exited 0 and matched schema 1, protocol 1, version 0.1.0, source commit 58676a23..., tuple, and self hash.
- make relay-asset-manifest-test: exit 0.
- make relay-asset-bundle-check: exit 0.
- Fresh generation into two independent directories: exit 0 each; recursive diff exit 0; diff against checked bundle exit 0.
- scripts/tests/test-generated-provider-graph.sh: exit 0.
- swift build --target ReluxTunnelIOSAdapter: exit 0.
- swift build --target ReluxTunnelMacOSAdapter: exit 0.
- make workspace-validate: exit 0.
- make macos-targets-validate: exit 0; unsigned host and provider products passed exact resource validation.
- make relay-protocol-check: exit 0.
- make check-core-boundaries: exit 0.
- swift format strict lint, Python compile, shell syntax, JSON parse, and git diff --check: exit 0.
- task-board validate: exit 0 while reporting current parent aggregate mismatch EPIC-260715-2lz67t backlog versus reviewing.

## HEV timing failure investigation

The producer recorded two broad swift test exits 1 in unchanged HEV tests. One saved rerun selected zero tests and the other covered only nonterminalRelayErrorsPreserveAssociation, so the original evidence was incomplete. Independent review ran swift test: exit 0, all 450 tests passed with the 25 expected known issues. replyValidationConsequences then passed 3 of 3 focused runs and nonterminalRelayErrorsPreserveAssociation passed 3 of 3 focused runs. No HEV production or test file is changed in this task. This supports out-of-scope timing flakiness rather than manifest regression, but the two producer broad-suite failures remain durable non-green historical evidence in this task resource.

## Policy and scope

Effective preflight for developer and reviewer permits only Codex, pins gpt-5.6-sol with high effort, and reports max_parallel 1. task-board.config.json, docs/spawn-policy.md, and .spec/goal-macos-v1.md agree on that policy and fresh independent Codex review. No signing, install, approval, app or provider launch, NetworkExtension preference mutation, startVPNTunnel, route, DNS, upload, or network operation was performed.

## Required rework

Bound every manifest and asset read before allocation, remove pathname reopen races, publish bundles atomically with safe replacement and cleanup, add oversized, symlink, path-safety, interruption, and replacement regressions, format every modified Python file, rerun all focused and Apple product gates, and preserve the broad-suite flake history.