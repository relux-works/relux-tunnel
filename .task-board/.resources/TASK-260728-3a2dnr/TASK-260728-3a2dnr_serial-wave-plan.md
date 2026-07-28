# Serial wave plan — macOS prototype critical path

Generated 2026-07-28 (rework round 3) by `.temp/TASK-260728-3a2dnr/waves.py`
against the **live** board, not hand-written. Re-run it after any dependency
change; the numbers below come from that run.

## How to read it

- The scheduler is `max_parallel = 1`, matching `docs/spawn-policy.md`: one
  tracked child at a time, producer → independent reviewer → rework → `done`.
- A **wave** is the set of tasks whose blockers are all accepted at that depth.
  With `max_parallel = 1` a wave is executed serially; wave numbers show
  ordering freedom, not concurrency.
- A **human-input node** is a task whose completion requires a human action or
  decision. It is a barrier and is **never** counted as an autonomous task, even
  when agent work runs inside the same node after the human's part (ADR-028).
  Each node states what the human actually does and what the agent then does
  unattended.
- Tasks with `blocked` status never complete in the simulation, so every
  deferred branch (iOS, Gate A0, `ReluxNIOSSH`) is sealed and cannot be
  scheduled (ADR-027).

## Answer to the task question

**The longest safe autonomous run to a working macOS client is autonomous
segment 3: 167 agent tasks in 26 waves**, carrying the board from the generated
macOS workspace through the M1 TCP/DNS system VPN, M2 relay/UDP/degraded mode,
and M3 resilience, with no human input inside it.

**The exact first human permission ceremony is `TASK-260728-q5kjta`** — one
sitting, reachable after autonomous segment 1 (23 tasks). Owner decision D1
(`TASK-260715-intsjz`) needs no Mac access and is asked in the same
conversation, so the first interruption is a single batch of two nodes.

The ordered shape:

| | what | size |
| --- | --- | --- |
| Segment 1 | harness core, relay assets, contract re-scope, identifier matrix | 23 agent tasks, 5 waves |
| **Batch C1** | **the permission sitting + owner decision D1** | 2 human nodes |
| Segment 2 | account readiness, portal mutations, notary check, Sparkle evidence, disposable probe | 5 agent tasks, 3 waves |
| **Batch A1** | approve the probe's system VPN / system extension (one click) | 1 human node |
| **Batch S1** | owner acknowledges the Gate P0 verdict | 1 human node |
| **Segment 3** | **the long run: M0 matrix → M1 → M2 → M3** | **167 agent tasks, 26 waves** |
| Batch H2+D2+D3+D4+R1+R2+L2 | real-app VPN approval, three owner decisions, two ratifications, legal notice review | 7 human nodes |
| Segment 4 | M1/M4 physical evidence, localization, accessibility | 20 agent tasks, 6 waves |
| Batch S2 | release identity/entitlement/migration contract approval | 1 human node |
| Segment 5 | release-contract follow-ups | 2 agent tasks, 2 waves |
| Batch C2+R3 | release environment ceremony + M5 ratification | 2 human nodes |
| Segment 6 | notarized DMG, appcast, signed publication | 9 agent tasks, 5 waves |
| Batch H3 / S3 / H4 | clean-system extension approval, rollback freeze approval, final acceptance run | 3 human nodes |

**226 autonomous agent tasks; 17 human-input nodes in 9 batches.**

## What changed in round 3, and why the count went down

Round 2 claimed 245 autonomous tasks. That number counted human-owned nodes
inside autonomous waves. Round 3 removed every such node from the autonomous
total and found six more the previous rounds had missed by reading each task's
own text rather than a hand-kept list:

- `TASK-260715-2ayxqn` AC5 — the accountable owner acknowledges the P0 verdict.
- `TASK-260717-1dsqnj`, `TASK-260717-l639qp`, `TASK-260717-2d308k` — each
  describes itself as a MANUAL ratification checkpoint that human owners perform.
- `TASK-260715-1r48pc`, `TASK-260715-2aessv` — clean-system acceptance runs of
  the Developer ID-signed candidate; the scope forbids bypassing system approval,
  and the release candidate's identity differs from the development build, so the
  H2 approval does not carry over.
- `TASK-260715-yynqbr` — the rollback rehearsal requires an owner freeze approval.

A scan of every reachable element's description, scope and AC for
human-decision language backs this list; the false positives (out-of-scope
mentions of TestFlight, "no manual Xcode edits", system-approval *guidance* in
UI copy, and physical runs that reuse an earlier approval) are excluded
deliberately, not by omission.

## Access preconditions that are evidenced, not assumed

`TASK-260715-39xz9g` (reproducible SSH matrix fixtures) requires access to a real
Relux SSH host. Round 2 flagged this as an unevidenced conditional hold. The
primary orchestrator has since run a read-only `BatchMode` probe against the
owner-authorized alias: authentication succeeded without a prompt and the remote
reports Darwin. No hostname, address, username, key path, credential, or remote
content was recorded — see
`TASK-260728-3a2dnr_relux-ssh-readiness.md`. Segment 1 is therefore genuinely
runnable with zero human input.

That probe is **not** conformance evidence: `39xz9g` still owes its own fixture
validation, and every SSH task still owes raw pre-auth host-key evidence before
auth acceptance.

## Residual risks stated rather than hidden

1. If the Apple portal forces a fresh two-factor challenge while `3jloqy`
   performs its mutations, that is one extra short interaction. It cannot be
   pre-granted; `3jloqy` records it rather than retrying silently.
2. Batches A1 and S1 are consecutive with one producer-reviewer cycle between
   them. They cannot be merged: S1 acknowledges a verdict that does not exist
   until `9yp8to` has been produced and reviewed.
3. Segment 3 is one 167-task serial run. Any red row inside it — for example an
   unsupported libssh2 window or rekey control — stays red and creates focused
   rework per `TASK-260715-1u2vpc` AC5; it is never waived to keep the run going.

---

# Serial execution plan — generated from the live DAG (max_parallel=1)

board tasks/bugs: 355   already done/closed: 62   deferred (`blocked`, sealed): 15

**autonomous agent tasks: 226**   **human-input nodes: 17 in 9 batches**   unreached behind seals: 34

A HUMAN node is never counted as autonomous. Agent work that merely uses access or a decision granted by an earlier HUMAN node is autonomous and is named as the follow-up of that node.


## Autonomous segment 1 — 23 agent tasks in 5 waves

- W1 (10): 135rr8 24icoz 29ws8l 2zmw58 39xz9g gyg51r ypo7yo 1s2eiz 2ohf99 yx2fca
- W2 (8): 12zaq5 13labb 1o9wjz 1ozsb6 1ue4oy 2jatnd 3f4lxy vtot05
- W3 (3): 2d3g5e 3cv3r4 mocqmr
- W4 (1): 1q03sa
- W5 (1): u8tkx0

## HUMAN BATCH C1 — 2 node(s), one interruption

- `TASK-260728-q5kjta` **C1** (ceremony) — conduct-c1-apple-permission-ceremony
  - human does: ONE sitting: unlock Keychain + always-allow signing keys; authenticate Xcode/Apple Developer portal incl. 2FA; authorize creation+download of the macOS packet-tunnel App IDs/capabilities/profiles; run notarytool store-credentials into a NAMED Keychain profile and state the source-file disposition; generate the Sparkle ed25519 keypair into custody
  - autonomous follow-up: apc34w (account readiness), 3jloqy (portal mutations + profile validation), dveo1o (notary auth check + custody verification), ziprhs (public-key evidence)
- `TASK-260715-intsjz` **C1** (decision) — decide-launch-locales-copy-ownership-and-fallback-policy
  - human does: owner decision: launch locales, copy ownership, fallback policy — no Mac access needed, asked in the same conversation as C1
  - autonomous follow-up: 1ets2m (externalize/localize M4 copy)

## Autonomous segment 2 — 5 agent tasks in 3 waves

- W1 (2): apc34w ziprhs
- W2 (2): 3jloqy dveo1o
- W3 (1): 1r0fxv

## HUMAN BATCH A1 — 1 node(s), one interruption

- `TASK-260715-9yp8to` **A1** (ceremony) — verify-p0-on-physical-apple-silicon-mac
  - human does: one click: approve the disposable probe's system-VPN dialog and the direct-distribution system-extension approval in System Settings
  - autonomous follow-up: the same node then runs manager save/reload, provider launch, app<->provider messaging, repeated stop, host termination, uninstall/reinstall, log capture — all unattended

## HUMAN BATCH S1 — 1 node(s), one interruption

- `TASK-260715-2ayxqn` **S1** (signoff) — record-gate-p0-disposition
  - human does: owner acknowledges the Gate P0 verdict and the downstream tasks it unblocks or leaves blocked (AC5) — asynchronous, not a sitting
  - autonomous follow-up: the report itself is agent-produced; only the acknowledgement is human

## Autonomous segment 3 — 167 agent tasks in 26 waves

- W1 (2): 1u2vpc 32umrc
- W2 (3): 1gjxer 2btjwm whtdsf
- W3 (5): 1pn983 2759wy 2wjvlx pa6evr uyju7n
- W4 (10): 1idq8c 2hef52 36gq4m 38atsq 3kimon 3kjhkw 82zzad sbrrp7 xempiv 3miqh4
- W5 (8): 1m3edc 2hhh7x 2ybl7y 3e7noa nphtib rk4mi7 33o8fc 3cveay
- W6 (9): 1uxx3i 28bwf4 29r0k8 2pml0c 2pwg4j 379cpk 3mk4hs d6x51z 1qhxqa
- W7 (9): 12tbjl 1e0x1u 1y5r8p 37rtzn 3ejhyy 3kepzm 6ig5xj a37ydn vg2of8
- W8 (8): 14flqo 1yxpqv 2lakiq 3dv8ea 3qqbbm 3t2v9w b6uruh m8bi8i
- W9 (11): 1c4l9v 1lmmri 1mr9j2 297imp 2rcvr0 2tj2pb 2uipar 2yz8du 31zqvw 3lab1f 2raag7
- W10 (6): 1jga46 1kfqgp 1m07fw 1n9v9o 3gp5wd 5o6jqg
- W11 (4): 1bj8hu 1dbmph 2hawz9 bf3a2d
- W12 (9): 1ex8i3 1fx855 1s9gku 2y9i1d 30ugfm 3260rm 393tuu 3pxgxx fve0hj
- W13 (5): 19lr1c 1gvdtz 1zikbu 293sz3 3b6krz
- W14 (6): 159pcp 1ge5hs 2s8zr1 2voayq 336ljl 3e8l6b
- W15 (4): 1o4h97 3e30tx 3f9kv8 9h7pf8
- W16 (5): 28jdml 2lfgwo 3edgwz 3gj0ad z37ay7
- W17 (6): 1iwpn0 1ut6ot 318m1v ak0s72 k6qq13 s3at1l
- W18 (5): 1cj49i 2px5ap cqm7m5 kxxujt uh8kk6
- W19 (6): 1gz4r9 1j30es 1je8v2 1vg1mb 2m7lwo 3j3luy
- W20 (11): 14u9bo 1r6k4t 1xsybm 200jez 24e2o1 2a1cp7 2bgp7x 2imxt0 2lodgq 2y78ah 3hxnbt
- W21 (9): 10phgg 1k3wsk 1m2xet 1ok93q 3425xv 37eem9 3btpxm 3ddzdd 3gv53h
- W22 (11): 17kzx9 2bo0xl 2drjj5 2o2oq0 330cst 34pn13 3kga9i 3rqfao kq7vqf pmg702 wz0mvf
- W23 (6): 2f44rv 39lo79 3h64k1 3hvz8n gfptap npvvmd
- W24 (3): 2wnw59 312zg8 o07tjd
- W25 (3): 132kb2 1h2nc3 k5uxim
- W26 (3): 2i7mld 38o3xg kblh3k

## HUMAN BATCH H2+D2+D3+D4+R1+R2+L2 — 7 node(s), one interruption

- `TASK-260715-3f4rhy` **H2** (ceremony) — verify-physical-provider-ssh-authentication
  - human does: one click: approve the system VPN / system extension for the REAL app, whose bundle identifier differs from the probe's, so the C1/A1 approvals do not carry over
  - autonomous follow-up: the same node then captures physical provider SSH authentication evidence
- `TASK-260715-35nc5m` **D2** (decision) — decide-legacy-socks-coexistence-replacement-or-retirement
  - human does: owner decision: legacy SOCKS coexist / replace / retire
  - autonomous follow-up: 1tzaed, migration and messaging tasks downstream
- `TASK-260715-3mnqn8` **D3** (decision) — decide-hev-fork-from-instruments-evidence
  - human does: owner approval: fork the vendored HEV dependency, only if the Instruments evidence justifies it
  - autonomous follow-up: the Instruments evidence and the recommendation are agent-produced
- `TASK-260715-2gwfaw` **D4** (decision) — approve-vpn-privacy-retention-and-support-copy
  - human does: owner/privacy/legal approval: VPN privacy, retention, and support copy
  - autonomous follow-up: diagnostics/privacy documentation tasks downstream
- `TASK-260717-1dsqnj` **R1** (signoff) — ratify-m1-runtime-routing-and-trust-contracts
  - human does: MANUAL governance checkpoint: human product/engineering owners ratify or return changes for the four M1 runtime/routing/trust contracts; silence is not approval (AC2)
  - autonomous follow-up: the contracts and the agent-reviewer verdicts are already produced
- `TASK-260717-l639qp` **R2** (signoff) — ratify-m3-policy-and-resilience-contracts
  - human does: MANUAL accountable ratification of the M3 QUIC/route-mode policy contract and the reconnect ownership contract before the final physical M3 matrix can be accepted
  - autonomous follow-up: the contracts and reviewer verdicts are already produced
- `TASK-260715-151xf0` **L2** (signoff) — assemble-third-party-notices-and-license-evidence
  - human does: dated legal or compliance review of the third-party notice set (AC5)
  - autonomous follow-up: the notice set and SBOM mapping are agent-produced

## Autonomous segment 4 — 20 agent tasks in 6 waves

- W1 (6): 12x6oq 1jtyre 3c7g17 6qqmsz nwcp1j yjpk5a
- W2 (5): 28y0uc 2wqffe 2zonmp 3nzx7s ixevcp
- W3 (4): 1fpr3u 1fwkrd 1z8ac2 qdpbd1
- W4 (3): 1ets2m 2unyf6 3c06k7
- W5 (1): 1fk4ja
- W6 (1): zwtrhy

## HUMAN BATCH S2 — 1 node(s), one interruption

- `TASK-260715-1tzaed` **S2** (signoff) — record-macos-release-identity-entitlement-and-migration-contract
  - human does: platform, security, release AND product owners approve the macOS release identity/entitlement/migration contract (AC5)
  - autonomous follow-up: the contract text is agent-produced

## Autonomous segment 5 — 2 agent tasks in 2 waves

- W1 (1): 30lksy
- W2 (1): go37ij

## HUMAN BATCH C2+R3 — 2 node(s), one interruption

- `TASK-260715-3gkwn0` **C2** (ceremony) — configure-developer-id-notary-and-macos-release-environment
  - human does: GitHub protected-environment secrets, required reviewers, publication token scope; Developer ID / notary release environment
  - autonomous follow-up: release workflow tasks downstream
- `TASK-260717-2d308k` **R3** (signoff) — ratify-m5-release-compliance-and-ci-trust-contracts
  - human does: MANUAL batch ratification: release, security and platform owners ratify the four M5 release-governance contracts before publication
  - autonomous follow-up: the contracts and reviewer verdicts are already produced

## Autonomous segment 6 — 9 agent tasks in 5 waves

- W1 (1): 3sk5cd
- W2 (2): 3s6yds 1mt4e7
- W3 (2): 387eof 3bj9bk
- W4 (2): 1gzhnk a8uhro
- W5 (2): 1njthi s4ox20

## HUMAN BATCH H3 — 1 node(s), one interruption

- `TASK-260715-1r48pc` **H3** (ceremony) — validate-macos-clean-install-upgrade-extension-and-uninstall
  - human does: approve the Developer ID-signed candidate's system extension on a CLEAN macOS system; the release candidate's signing/distribution differs from the development build, so the H2 approval does not carry over, and the scope forbids bypassing system approval
  - autonomous follow-up: the same node then runs Gatekeeper launch, install/upgrade, synthetic connect smoke, relaunch and uninstall unattended

## HUMAN BATCH S3 — 1 node(s), one interruption

- `TASK-260715-yynqbr` **S3** (signoff) — exercise-macos-rollback-withdrawal-and-credential-revocation
  - human does: owner declares the bad candidate and approves the promotion freeze during the rollback rehearsal (scope: 'bad-candidate declaration, freeze and owner approval')
  - autonomous follow-up: withdrawal, restore, provenance verification and credential rotation are agent-run

## HUMAN BATCH H4 — 1 node(s), one interruption

- `TASK-260715-2aessv` **H4** (ceremony) — run-macos-distribution-acceptance-matrix
  - human does: approve the system extension on each clean acceptance system for the final independent distribution gate; AC2 requires real system-approval rows and the scope forbids human approval without recorded evidence
  - autonomous follow-up: archive/entitlement/signature/notarization/Gatekeeper/digest inspection and the evidence index are agent-run


## Deferred — `blocked` with evidence packets (15)

- `TASK-260715-13gzxe` verify-ios-physical-lifecycle-and-ui-independence
- `TASK-260715-1a1fwv` run-iphone-nat64-sleep-captive-matrix
- `TASK-260715-1af33i` integrate-reluxniossh-candidate-adapter
- `TASK-260715-1jckn0` build-disposable-ios-packet-tunnel-probe
- `TASK-260715-1kntdx` verify-p0-on-physical-iphone
- `TASK-260715-1kpnkl` provision-isolated-app-review-ssh-test-environment
- `TASK-260715-1o3q6l` compile-gate-a0-primary-source-dossier
- `TASK-260715-2hiabd` implement-ios-packet-tunnel-provider-adapter
- `TASK-260715-2kfa02` run-iphone-udp-and-dns-exit-validation
- `TASK-260715-2qr5aj` verify-ios-routing-dns-and-leak-evidence
- `TASK-260715-2yywzw` build-ios-onboarding-and-vpn-permission-journey
- `TASK-260715-33oofa` add-ios-host-and-packet-tunnel-targets
- `TASK-260715-3ix830` build-ios-vpn-connection-dashboard
- `TASK-260715-3nkhry` run-iphone-full-degraded-recovery-validation
- `TASK-260715-n8i3tv` build-ios-profile-and-key-management-ui

## Unreached behind deferred branches or later holds (34)

- `TASK-260715-11wjue` assemble-and-audit-app-review-submission-package
- `TASK-260715-12avq0` author-and-review-a0-disclosure-packet
- `TASK-260715-13y6hb` triage-app-review-feedback-and-resubmit
- `TASK-260715-1828xy` record-gate-a0-disposition
- `TASK-260715-1bni66` validate-app-store-binary-technical-preflight
- `TASK-260715-1g658s` write-cross-platform-rollback-incident-and-revocation-runbook
- `TASK-260715-1i6bh7` obtain-authoritative-apple-a0-evidence
- `TASK-260715-1lkgxh` record-ios-source-to-archive-provenance-and-reproducibility
- `TASK-260715-1quopg` exercise-testflight-withdrawal-supersession-and-credential-revocation
- `TASK-260715-1qwp3f` prepare-app-store-metadata-screenshots-and-support-urls
- `TASK-260715-1vo4rm` allocate-ios-marketing-version-and-build-number
- `TASK-260715-26wi46` prepare-vpn-data-flow-entitlement-and-review-evidence
- `TASK-260715-2dxzjv` author-reproducible-app-review-test-instructions
- `TASK-260715-2e6i0a` submit-ios-candidate-to-app-review
- `TASK-260715-2k812u` publish-versioned-public-vpn-privacy-policy
- `TASK-260715-2vhtqg` audit-privacy-legal-review-claims-against-candidate
- `TASK-260715-2xx2tk` run-comparative-ssh-scale-memory-and-lifecycle-matrix
- `TASK-260715-2y4gpx` verify-published-channels-and-open-rollback-watch
- `TASK-260715-30ch0z` validate-ios-privacy-symbols-apis-and-encryption-inventory
- `TASK-260715-312u2k` record-release-readiness-go-no-go-decision
- `TASK-260715-3661ps` record-ios-distribution-signing-version-and-testflight-contract
- `TASK-260715-3a92td` run-physical-testflight-vpn-lifecycle-matrix
- `TASK-260715-3c2ukn` obtain-regional-vpn-licensing-and-storefront-decision
- `TASK-260715-3cg87m` revalidate-current-apple-review-privacy-export-and-vpn-requirements
- `TASK-260715-3dno4w` inspect-ios-profiles-entitlements-bundle-and-architectures
- `TASK-260715-3ikonq` run-reluxniossh-functional-and-rekey-matrix
- `TASK-260715-3ixjf7` produce-ios-distribution-acceptance-evidence
- `TASK-260715-3rdsap` execute-cross-platform-release-candidate-regression-matrix
- `TASK-260715-6j1u2g` write-cross-platform-release-operations-runbook
- `TASK-260715-8g5fpa` configure-app-store-connect-and-ios-distribution-environment
- `TASK-260715-dsvvnu` assemble-and-export-ios-app-store-archive
- `TASK-260715-sfkrzq` upload-process-and-distribute-testflight-candidate
- `TASK-260715-x4h9n1` assess-a0-evidence-and-pivot-options
- `TASK-260715-zbd75q` complete-app-privacy-labels-export-and-legal-declarations
