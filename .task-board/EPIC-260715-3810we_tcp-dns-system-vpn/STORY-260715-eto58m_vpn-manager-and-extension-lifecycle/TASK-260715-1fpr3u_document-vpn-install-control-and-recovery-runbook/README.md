# Document VPN installation, control, state, and recovery

## Description
Write the developer and operator runbook for creating or updating the Relux manager, granting system permission, connecting, interpreting combined session and capability state, collecting privacy-safe provider diagnostics, disconnecting, removing an owned configuration, and recovering from supported M1 lifecycle errors.

## Scope
In scope: both generated platforms, owned-manager rules, permission differences, start and stop boundaries, app-message compatibility, host termination behavior, error codes, stale manager recovery, clean uninstall guidance, test commands, and M0 or later-milestone links. Out of scope: final onboarding copy, screenshots for store submission, reconnect operations, fail-closed claims, release signing, notarization, and editing product code.

## Acceptance Criteria
1. Runbook steps match the implemented APIs and never instruct operators to remove unrelated VPN configurations. 2. A state table combines Network Extension session states with provider capability and diagnostic availability. 3. Separate iOS and macOS sections cover permission, host termination or relaunch, stop reason, stale configuration, and safe recovery. 4. Commands or procedures reproduce automated lifecycle tests and both physical-device evidence tasks. 5. Documentation states M1 limitations and links reconnect, route modes, final UI, and distribution work to M3, M4, and M5.
