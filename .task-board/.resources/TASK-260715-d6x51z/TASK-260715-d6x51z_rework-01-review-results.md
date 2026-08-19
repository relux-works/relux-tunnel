# TASK-260715-d6x51z focused rework review

## Verdict

ACCEPTED. The reviewer-requested signing-boundary rework is complete.

## Evidence

The prior independent review evidence remains accepted for ownership, exact commands, links, manifests, target graph, architecture fit, and documentation completeness at source revision d18847cd6d7f3b84bdd807eddbca37d9259945de.

Focused inspection confirms:

- README.md labels Probes/macOSPacketTunnelProbe/Scripts/build-and-inspect.sh as dedicated-host-only, states that signing and probe execution are prohibited on the build host, and links docs/build-host-safety.md.
- docs/build-host-safety.md explicitly prohibits code-signing an app, provider, archive, or Gate P0 probe and prohibits running the signed Gate P0 probe on this host.
- CONTRIBUTING.md repeats both prohibitions and explicitly distinguishes product signing from the required signed Git commit policy.
- The three documents are mutually consistent and contain no credential bytes, private signing paths, build-host authorization, physical-VPN claim, or shipping claim.

## Focused verification

- Focused local Markdown link validation: exit 0.
- Focused documentation safety and credential/private-path scans: exit 0.
- git diff --check: exit 0.
- ./scripts/tests/test-credential-free-validation.sh: exit 0.
- task-board validate before verdict attachment: exit 0.

Three preliminary link-validator attempts exited 1 and are retained as real diagnostic results: the first had shell quoting rejected before file inspection; the second incorrectly traversed generated .build and dependency checkout Markdown; the third included .task-board resource links with non-filesystem semantics. Each scope defect was corrected without changing documentation. The contract-scoped validator over README.md, CONTRIBUTING.md, and docs/build-host-safety.md exited 0.

The full credential-free build matrix was intentionally not rerun per the focused review contract. No signing, credential inspection, installation, app/provider launch, VPN preference save or activation, route mutation, or DNS mutation was performed. No commit was made and no commit_ack was supplied.