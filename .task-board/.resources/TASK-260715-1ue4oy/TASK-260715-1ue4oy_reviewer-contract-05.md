# TASK-260715-1ue4oy fresh review 05

Independently review the current uncommitted implementation. Do not trust producer claims or prior green verdicts. Focus on rework 04 and regressions; use prior passing evidence to avoid repeating unrelated repository discovery.

## Blocking acceptance checks

1. Reproduce the former validation-to-`lstat` race: when the first parent-fd-anchored observation says absent, create a foreign destination immediately afterward. Generation must fail, preserve exact device/inode and marker bytes, and remove only owned staging.
2. Audit the state model from the initial observation through `publish_staged_bundle`. The initial no-replace intent must never be reclassified by later pathname state.
3. Adversarially check the symmetric existing-destination case: if initial observation sees directory A, and A is replaced by foreign directory B before publication, B must not be exchanged/deleted. Replacement is permitted only for the identity that the attempt initially observed and validated. If current code cannot prove/preserve this, request changes with a deterministic reproduction.
4. Reconfirm earlier safety properties remain intact: descriptor/no-follow bounded reads, same-descriptor archive validation, fd ownership, atomic no-replace/exchange, identity-checked cleanup, and interruption recovery.
5. Run the focused 21 Python tests, manifest Make target, formatter/compile/diff checks, and only the broader gates proportionate to changed code. Prior unsigned Apple/product and 450-test evidence may be spot-checked rather than blindly repeated unless the delta affects it.

## Verdict routing

- Accept only with independent evidence, checklist reviewer items checked, and the task routed according to the configured VCS confirmation workflow. Do not commit.
- On any blocking issue, attach a task-scoped verdict and route to `to-dev`.

## Build-host safety

Do not sign, install, or launch the app/provider; do not save/remove/enable VPN preferences; do not call `startVPNTunnel`; do not alter routes, interfaces, DNS, or firewall state. Local unsigned builds and rootless harness commands only.
