# Independent review contract — TASK-260715-u8tkx0

Act as a fresh second operator. Do not trust the producer summary or merely proofread Markdown.

1. Read the task AC, producer outcome, `docs/relay-asset-release-runbook.md`, linked supply-chain docs, and the current implementation targets they cite.
2. Follow the documented build/audit procedure from a fresh task-scoped temporary root. Rebuild all four assets twice, compare exact bytes and archive with retained evidence, regenerate/check both manifest layers, and execute the supported native Darwin arm64 smoke. Never install or start a VPN, modify NetworkExtension preferences, routing, DNS, interfaces, or `pf`.
3. Verify every command is copy-paste executable from the stated directory and that expected success/failure outputs are accurate. Exercise at least the documented hash-drift/mismatch and unsupported-runtime red paths without using remote unverified bytes.
4. Verify the strict update order, rollback preserving known exact bytes/manifest, compromised-asset response, credential-safe evidence rules, and separation of M2 unsigned bundle work from M5 signing/notary/release ceremonies.
5. Resolve every concrete task ID in the M2/M5 ownership and downstream-consumer tables against the live board; reject stale or semantically wrong ownership links.
6. Check RACI separation for source, hash, signing, notarization, attestation, approval, notices, and rollback. Confirm the relay is not represented as a standalone signed download.
7. Inspect the complete diff and links for contradictions, absolute-path leakage, secrets, or unsafe build-host instructions. Run `task-board validate` and relevant focused docs/build gates.

Verdict rules:
- Accept only with independently reproduced evidence and move the task to `done` using the reviewer role contract.
- If anything is inaccurate or non-executable, preserve exact findings in a task-scoped reviewer outcome and return to `to-dev`.
- Do not commit or push. Do not perform real VPN/system-network testing.
