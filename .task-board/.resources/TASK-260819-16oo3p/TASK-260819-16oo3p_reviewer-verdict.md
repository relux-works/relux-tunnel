# TASK-260819-16oo3p reviewer verdict

## Verdict

Changes requested. Route to development.

## Blocking finding

The production preflight does not fail closed because scripts/physical-test-host-preflight.sh allows RELUX_BUILD_ONLY_HOSTS_FILE to replace the authoritative repository denylist. On the registered build host, the following preflight-only reproduction was accepted with exit 0:

RELUX_BUILD_ONLY_HOSTS_FILE=/dev/null RELUX_PHYSICAL_TEST_OPT_IN=dedicated-mac-only RELUX_PHYSICAL_TEST_HOST="$(hostname -s)" scripts/physical-test-host-preflight.sh

Output: PASS: dedicated physical-test host identity accepted

This command only evaluated the safety preflight. It did not install/open an app or system extension, access/save/remove NetworkExtension preferences, start/activate a tunnel or provider, or mutate routes/DNS.

The repository fingerprint was independently confirmed to match this Mac using the production hashing algorithm (exit 0), so the acceptance is caused by the denylist override rather than stale host registration.

## Required rework

- Make the production entrypoint always use the repository-owned config/build-only-hosts.sha256 and ignore/reject caller-controlled denylist overrides.
- Keep synthetic denylist injection confined to the pure validation function/tests.
- Add an entrypoint regression test proving RELUX_BUILD_ONLY_HOSTS_FILE cannot bypass current-build-host rejection.

## Other review evidence

- Probes/macOSPacketTunnelProbe/Scripts/test-physical-gate-p0.sh: exit 0.
- task-board validate: exit 0.
- bash -n changed shell scripts: exit 0.
- shellcheck changed shell scripts: exit 0.
- git diff --check: exit 0.
- make core-test core-build: exit 0; 443 tests passed with 25 recorded known issues; Swift build passed.
- Dependency audit supports 19 active M1-M5 macOS network-mutating tasks gated by TASK-260819-25e1ys. M0 physical SPM harness tasks are within the explicitly allowed local harness scope.
