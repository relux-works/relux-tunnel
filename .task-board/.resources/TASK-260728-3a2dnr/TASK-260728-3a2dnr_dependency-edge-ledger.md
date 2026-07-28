# Complete dependency-edge ledger — TASK-260728-3a2dnr

Every edge this task removed or added, derived mechanically from the board diff
by `.temp/TASK-260728-3a2dnr/edge_audit.py` (parses the `## Blocked By` section of
every `progress.md` at `git HEAD` and in the working tree). Nothing is sampled.
Notation `X <- Y` means *X is blocked by Y*.

- removed: **75** — 37 task-to-task, 38 container-involving
- added: **21** — all task-to-task
- elements deleted: **0** (none — no task, resource, note or evidence was destroyed)
- elements created: `TASK-260728-3a2dnr`, `TASK-260728-3bj9bk`, `TASK-260728-3cveay`, `TASK-260728-dveo1o`, `TASK-260728-q5kjta`, `TASK-260728-yx2fca`

## Removed task-to-task edges

### iOS deferral (ADR-024 + ADR-027) — 26 edge(s)

| removed edge | blocker reachability | blocked task keeps | reason |
| --- | --- | --- | --- |
| `132kb2` verify-physical-system-vpn-status-and-host-lifecycle **<-** `3nkhry` run-iphone-full-degraded-recovery-validation | `blocked` (sealed root) | `312zg8`, `3lab1f`, `10phgg`, `3hvz8n` | iPhone full/degraded recovery run; the macOS M2 counterpart TASK-260715-10phgg is retained and this task's AC now records the iPhone row as a named deferred gap. |
| `1ets2m` externalize-localize-and-pseudolocalize-m4-copy **<-** `2yywzw` build-ios-onboarding-and-vpn-permission-journey | `blocked` (sealed root) | `intsjz`, `2gwfaw`, `2lakiq`, `2y9i1d`, `1ex8i3`, `1fx855`, `17kzx9`, `kq7vqf`, `wz0mvf`, `3h64k1`, `3c7g17`, `6qqmsz`, `qdpbd1`, `1fwkrd` | iOS onboarding UI; macOS counterpart TASK-260715-qdpbd1 retained. |
| `1ets2m` externalize-localize-and-pseudolocalize-m4-copy **<-** `3ix830` build-ios-vpn-connection-dashboard | `blocked` (sealed root) | `intsjz`, `2gwfaw`, `2lakiq`, `2y9i1d`, `1ex8i3`, `1fx855`, `17kzx9`, `kq7vqf`, `wz0mvf`, `3h64k1`, `3c7g17`, `6qqmsz`, `qdpbd1`, `1fwkrd` | iOS dashboard UI; macOS counterpart TASK-260715-17kzx9 retained. |
| `1ets2m` externalize-localize-and-pseudolocalize-m4-copy **<-** `n8i3tv` build-ios-profile-and-key-management-ui | `blocked` (sealed root) | `intsjz`, `2gwfaw`, `2lakiq`, `2y9i1d`, `1ex8i3`, `1fx855`, `17kzx9`, `kq7vqf`, `wz0mvf`, `3h64k1`, `3c7g17`, `6qqmsz`, `qdpbd1`, `1fwkrd` | iOS profile/key UI; macOS counterpart TASK-260715-2lakiq retained. |
| `1fk4ja` add-onboarding-migration-localization-and-accessibility-ui-tests **<-** `2yywzw` build-ios-onboarding-and-vpn-permission-journey | `blocked` (sealed root) | `qdpbd1`, `1jtyre`, `2unyf6`, `1ets2m`, `1fwkrd`, `1idq8c` | iOS onboarding UI; macOS counterpart TASK-260715-qdpbd1 retained. |
| `1fpr3u` document-vpn-install-control-and-recovery-runbook **<-** `13gzxe` verify-ios-physical-lifecycle-and-ui-independence | `blocked` (sealed root) | `3lab1f`, `3f4rhy`, `12x6oq`, `2wqffe` | iOS physical lifecycle; macOS counterpart TASK-260715-12x6oq retained. |
| `1fpr3u` document-vpn-install-control-and-recovery-runbook **<-** `2qr5aj` verify-ios-routing-dns-and-leak-evidence | `blocked` (sealed root) | `3lab1f`, `3f4rhy`, `12x6oq`, `2wqffe` | iOS routing/DNS-leak evidence; macOS counterparts TASK-260715-2wqffe and TASK-260715-3f4rhy retained, so the DNS-leak gate still binds. |
| `1h2nc3` document-platform-exception-support-matrix **<-** `1a1fwv` run-iphone-nat64-sleep-captive-matrix | `blocked` (sealed root) | `2wnw59` | iPhone NAT64/sleep/captive matrix; macOS counterpart TASK-260715-2wnw59 retained. |
| `1idq8c` establish-shared-apple-ui-test-infrastructure **<-** `33oofa` add-ios-host-and-packet-tunnel-targets | `blocked` (sealed root) | `uyju7n` | iOS host/extension targets; the generated macOS targets (TASK-260715-uyju7n chain) remain the real precondition. |
| `1kfqgp` add-profile-and-key-cross-platform-ui-tests **<-** `n8i3tv` build-ios-profile-and-key-management-ui | `blocked` (sealed root) | `2lakiq`, `1yxpqv`, `1idq8c`, `2raag7` | iOS profile/key UI; macOS counterpart TASK-260715-2lakiq retained. |
| `1lmmri` enforce-apple-bundle-relay-selection-and-integrity **<-** `33oofa` add-ios-host-and-packet-tunnel-targets | `blocked` (sealed root) | `14flqo`, `uyju7n`, `nphtib` | iOS targets; macOS bundle/relay integrity still gated by the macOS target chain. |
| `1uxx3i` add-credential-free-apple-target-build-matrix **<-** `33oofa` add-ios-host-and-packet-tunnel-targets | `blocked` (sealed root) | `whtdsf`, `2wjvlx`, `nphtib`, `uyju7n` | iOS targets; the credential-free build matrix keeps its macOS target dependencies. |
| `24e2o1` document-udp-limits-metrics-and-operations **<-** `2kfa02` run-iphone-udp-and-dns-exit-validation | `blocked` (sealed root) | `cqm7m5`, `2m7lwo` | iPhone UDP/DNS exit validation; macOS counterpart TASK-260715-2m7lwo retained. |
| `2ayxqn` record-gate-p0-disposition **<-** `1kntdx` verify-p0-on-physical-iphone | `blocked` (sealed root) | `9yp8to` | physical-iPhone P0; the macOS P0 run TASK-260715-9yp8to is retained as the sole blocker and AC1/AC2 now record the iPhone bundle as a named deferred gap that is never inferred from Mac results. |
| `2unyf6` implement-m4-accessibility-semantics-focus-and-motion **<-** `2yywzw` build-ios-onboarding-and-vpn-permission-journey | `blocked` (sealed root) | `2lakiq`, `2y9i1d`, `1ex8i3`, `1fx855`, `17kzx9`, `kq7vqf`, `wz0mvf`, `3h64k1`, `3c7g17`, `6qqmsz`, `qdpbd1`, `1fwkrd` | iOS onboarding UI; macOS counterpart TASK-260715-qdpbd1 retained. |
| `2unyf6` implement-m4-accessibility-semantics-focus-and-motion **<-** `3ix830` build-ios-vpn-connection-dashboard | `blocked` (sealed root) | `2lakiq`, `2y9i1d`, `1ex8i3`, `1fx855`, `17kzx9`, `kq7vqf`, `wz0mvf`, `3h64k1`, `3c7g17`, `6qqmsz`, `qdpbd1`, `1fwkrd` | iOS dashboard UI; macOS counterpart TASK-260715-17kzx9 retained. |
| `2unyf6` implement-m4-accessibility-semantics-focus-and-motion **<-** `n8i3tv` build-ios-profile-and-key-management-ui | `blocked` (sealed root) | `2lakiq`, `2y9i1d`, `1ex8i3`, `1fx855`, `17kzx9`, `kq7vqf`, `wz0mvf`, `3h64k1`, `3c7g17`, `6qqmsz`, `qdpbd1`, `1fwkrd` | iOS profile/key UI; macOS counterpart TASK-260715-2lakiq retained. |
| `312zg8` add-connection-cross-platform-ui-and-accessibility-tests **<-** `3ix830` build-ios-vpn-connection-dashboard | `blocked` (sealed root) | `17kzx9`, `kq7vqf`, `wz0mvf`, `34pn13`, `39lo79`, `1idq8c` | iOS dashboard UI; macOS counterparts TASK-260715-17kzx9, kq7vqf, wz0mvf retained. |
| `3kga9i` document-capability-modes-limitations-and-diagnostics **<-** `3nkhry` run-iphone-full-degraded-recovery-validation | `blocked` (sealed root) | `2y78ah`, `10phgg` | iPhone full/degraded recovery; macOS counterpart TASK-260715-10phgg retained. |
| `3lab1f` add-vpn-manager-and-provider-lifecycle-tests **<-** `2hiabd` implement-ios-packet-tunnel-provider-adapter | `blocked` (sealed root) | `15vkvz`, `1rsqrh`, `3dv8ea`, `1bp6eu` | iOS provider adapter; the macOS provider adapter chain is retained. |
| `k5uxim` capture-untuned-iphone-mac-baselines **<-** `1a1fwv` run-iphone-nat64-sleep-captive-matrix | `blocked` (sealed root) | `1ok93q`, `37eem9`, `1k3wsk`, `3hvz8n`, `gfptap`, `2wnw59` | iPhone NAT64/sleep/captive matrix; macOS counterpart TASK-260715-2wnw59 retained. |
| `sbrrp7` add-credential-free-project-build-validation **<-** `33oofa` add-ios-host-and-packet-tunnel-targets | `blocked` (sealed root) | `uyju7n`, `2nfz7w`, `1g9cyt`, `pmww4f`, `1ccx3l`, `14lk3y` | iOS targets; macOS project build validation keeps its macOS target dependencies. |
| `zwtrhy` run-physical-m4-product-security-and-accessibility-matrix **<-** `2qr5aj` verify-ios-routing-dns-and-leak-evidence | `blocked` (sealed root) | `1fk4ja`, `1kfqgp`, `3b6krz`, `132kb2`, `3nzx7s`, `3f4rhy`, `2wqffe`, `10phgg`, `3hvz8n` | iOS routing/DNS-leak evidence; macOS counterparts retained. |
| `zwtrhy` run-physical-m4-product-security-and-accessibility-matrix **<-** `3nkhry` run-iphone-full-degraded-recovery-validation | `blocked` (sealed root) | `1fk4ja`, `1kfqgp`, `3b6krz`, `132kb2`, `3nzx7s`, `3f4rhy`, `2wqffe`, `10phgg`, `3hvz8n` | iPhone recovery matrix; macOS counterpart TASK-260715-10phgg retained. |
| `2d308k` ratify-m5-release-compliance-and-ci-trust-contracts **<-** `3661ps` record-ios-distribution-signing-version-and-testflight-contract | `backlog` but unreachable, sealed behind `1o3q6l` | `whtdsf`, `1tzaed`, `pa6evr` | iOS distribution/signing/TestFlight contract; the other three M5 governance contracts (whtdsf, 1tzaed, pa6evr) remain blockers, so the ratification checkpoint still consumes every non-deferred contract. |
| `2raag7` add-explicit-exit-resolver-profile-experience **<-** `n8i3tv` build-ios-profile-and-key-management-ui | `blocked` (sealed root) | `33o8fc`, `28bwf4`, `1y5r8p`, `2lakiq`, `3miqh4` | iOS profile/key UI; macOS counterpart TASK-260715-2lakiq retained. |

### NIOSSH deferral (ADR-014 + ADR-027) — 3 edge(s)

| removed edge | blocker reachability | blocked task keeps | reason |
| --- | --- | --- | --- |
| `1gjxer` record-m0-ssh-engine-selection **<-** `2xx2tk` run-comparative-ssh-scale-memory-and-lifecycle-matrix | `backlog` but unreachable, sealed behind `1af33i` | `1u2vpc` | comparative NIOSSH scale/memory matrix; the libssh2 matrix TASK-260715-1u2vpc is retained as the blocker, so engine selection still rests on real matrix evidence. |
| `1gjxer` record-m0-ssh-engine-selection **<-** `3ikonq` run-reluxniossh-functional-and-rekey-matrix | `backlog` but unreachable, sealed behind `1af33i` | `1u2vpc` | NIOSSH functional/rekey matrix; same retained libssh2 matrix. |
| `2d3g5e` add-common-ssh-transport-conformance-tests **<-** `1af33i` integrate-reluxniossh-candidate-adapter | `blocked` (sealed root) | `2ny6z4`, `1ozsb6`, `39xz9g`, `100wu6`, `yx2fca` | NIOSSH adapter integration; the conformance suite is candidate-neutral and keeps TASK-260728-yx2fca and TASK-260715-39xz9g, so host-key-before-auth conformance is unchanged. |

### Gate A0 deferral (ADR-013 + ADR-027) — 3 edge(s)

| removed edge | blocker reachability | blocked task keeps | reason |
| --- | --- | --- | --- |
| `1tzaed` record-macos-release-identity-entitlement-and-migration-contract **<-** `1828xy` record-gate-a0-disposition | `backlog` but unreachable, sealed behind `1o3q6l` | `2ayxqn`, `32umrc`, `uyju7n`, `35nc5m`, `24icoz` | Gate A0 disposition; the macOS release identity contract keeps 2ayxqn (Gate P0), 32umrc, uyju7n, 35nc5m and 24icoz. |
| `32umrc` record-generated-project-architecture-adr **<-** `1828xy` record-gate-a0-disposition | `backlog` but unreachable, sealed behind `1o3q6l` | `1fv4z1`, `3r0993`, `3bdplx`, `2ayxqn` | Gate A0 disposition; the generated-project ADR keeps TASK-260715-2ayxqn, so Gate P0 still gates it. |
| `whtdsf` record-ci-trust-and-quality-gate-contract **<-** `1828xy` record-gate-a0-disposition | `backlog` but unreachable, sealed behind `1o3q6l` | `32umrc` | Gate A0 disposition; the CI trust contract keeps 32umrc, which is itself blocked by 2ayxqn. |

### dependency-cycle repair — 2 edge(s)

| removed edge | blocker reachability | blocked task keeps | reason |
| --- | --- | --- | --- |
| `1pn983` record-memory-window-rekey-contract **<-** `30ugfm` integrate-safe-routing-dns-startup-and-failure-order | `backlog` — reachable | `2jatnd`, `1gjxer` | broke the live cycle 3miqh4 -> 1pn983 -> 30ugfm -> {2tj2pb -> 2pml0c -> 33o8fc | 5o6jqg} -> 3miqh4. The memory/window/rekey contract is an input to routing integration, not an output of it; 1pn983 keeps 2jatnd and 1gjxer. |
| `1pn983` record-memory-window-rekey-contract **<-** `z37ay7` enforce-udp-resource-limits-and-dns-priority | `backlog` — reachable | `2jatnd`, `1gjxer` | direction flip in the same cycle repair; the reverse edge z37ay7 <- 1pn983 was added, so UDP resource limits still consume the memory/window/rekey contract. |

### ceremony ordering (ADR-028) — 1 edge(s)

| removed edge | blocker reachability | blocked task keeps | reason |
| --- | --- | --- | --- |
| `ypo7yo` define-apple-identifier-and-entitlement-matrix **<-** `apc34w` verify-relux-works-apple-account-readiness | `backlog` — reachable | *(no blockers)* | the identifier/entitlement matrix must exist BEFORE the ceremony authorizes anything, so the matrix cannot depend on account readiness. The order is preserved by two added edges: q5kjta <- ypo7yo and 3jloqy <- apc34w. |

### superseded by a stricter edge — 1 edge(s)

| removed edge | blocker reachability | blocked task keeps | reason |
| --- | --- | --- | --- |
| `1njthi` publish-versioned-and-stable-authenticated-github-assets **<-** `ziprhs` generate-and-install-sparkle-eddsa-update-signing-secret | `backlog` — reachable | `387eof`, `1gzhnk`, `2ybl7y`, `2759wy`, `3bj9bk` | replaced by the stricter edge 1njthi <- TASK-260728-3bj9bk, which is itself blocked by ziprhs, xempiv and 1mt4e7. Publication now requires real appcast signing evidence, not merely a generated key (ADR-026). |

### redundant edge, gate still transitively enforced — 1 edge(s)

| removed edge | blocker reachability | blocked task keeps | reason |
| --- | --- | --- | --- |
| `whtdsf` record-ci-trust-and-quality-gate-contract **<-** `2ayxqn` record-gate-p0-disposition | `backlog` — reachable | `32umrc` | the CI trust and quality-gate contract keeps blocker 32umrc, which is blocked by 2ayxqn, so Gate P0 still transitively precedes it. Removing the direct edge changes no ordering; it only removes a duplicate. |

## Removed container-involving edges — 38

All 38 were unsupported container-to-container dependency links removed by
`task-board repair-links`. They also carried the four container-level cycles present
at `HEAD` (`2bfjhn <-> 1zzt0c`, `3810we -> 2qzczm -> 2lz67t -> 3810we`,
`c1qsc6 <-> 2byjks`, `w5gzf4 <-> 3fyjn0`). `task-board repair-links` now reports
*No suspicious container links found*, and `task-board validate` is clean.

For each edge the ledger states whether the same ordering is still enforced at task
level (checked live: does any task in the blocked container have a transitive
task-level blocker inside the blocker container?).

| removed container edge | ordering still enforced task-level | disposition |
| --- | --- | --- |
| `3810we` **<-** `2qzczm` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `3fyjn0` **<-** `21g2pi` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `3fyjn0` **<-** `2mqgvm` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `3fyjn0` **<-** `2qzczm` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `3fyjn0` **<-** `3810we` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `3fyjn0` **<-** `w5gzf4` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `18ncz1` **<-** `2itwz7` | **no** | intentional — Gate A0 no longer gates relay-protocol conformance (ADR-013); the story is already `done`. |
| `19ii11` **<-** `3ao1u9` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `1nsw9p` **<-** `3pv7qc` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `1zzt0c` **<-** `2bfjhn` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `243sh0` **<-** `2itwz7` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `243sh0` **<-** `2xnj3v` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `243sh0` **<-** `309t4z` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `243sh0` **<-** `n5dt84` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `2bfjhn` **<-** `1zzt0c` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `2dtdql` **<-** `2bfjhn` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `2dtdql` **<-** `2itwz7` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `2dtdql` **<-** `3tds7d` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `2dtdql` **<-** `c1qsc6` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `3ao1u9` **<-** `2ungml` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `anxje6` **<-** `2itwz7` | **no** | intentional — Gate A0 no longer gates CI quality gates (ADR-013). |
| `anxje6` **<-** `2xnj3v` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `c1qsc6` **<-** `2itwz7` | **no** | intentional and owner-approved — the macOS release is Developer ID-signed, notarized, directly distributed and never passes App Review, so Gate A0 does not gate it (ADR-013). A0 stays mandatory before App Store distribution. |
| `c1qsc6` **<-** `2xnj3v` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `c1qsc6` **<-** `309t4z` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `c1qsc6` **<-** `n5dt84` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `eto58m` **<-** `2bfjhn` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `eto58m` **<-** `2nqxa5` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `eto58m` **<-** `2wjwuf` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `l2i2oo` **<-** `2xnj3v` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `lkshfz` **<-** `2xnj3v` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `lkshfz` **<-** `jnpbyz` | **no** | intentional — the SSH engine spike and the packet-bridge/HEV spike are independent M0 workstreams on the SPM harness (ADR-011); keeping the edge would also have imported the packet-bridge story's physical-iPhone gate into engine selection. Real ordering is still enforced where it exists: `1u2vpc <- 2ayxqn` (Gate P0) and `2d3g5e <- 39xz9g`. |
| `n5dt84` **<-** `1y04r0` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `n5dt84` **<-** `2txwb7` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `n5dt84` **<-** `2ungml` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `n5dt84` **<-** `eto58m` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `n5dt84` **<-** `l2i2oo` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |
| `2byjks` **<-** `c1qsc6` | yes | no ordering lost — task-level blockers already reach into the blocker subtree |

## Added edges — 21

| added edge | reason |
| --- | --- |
| `1c4l9v` execute-relay-release-asset-validation-matrix **<-** `24icoz` build-four-platform-relay-assets | the relay release-asset validation matrix consumes the built relay assets. |
| `1njthi` publish-versioned-and-stable-authenticated-github-assets **<-** `3bj9bk` pin-sparkle-public-key-and-verify-appcast-signing | publication requires verified appcast signing. |
| `1ozsb6` integrate-libssh2-candidate-adapter **<-** `yx2fca` rescope-ssh-transport-contract-to-m0-viability | the libssh2 adapter cannot start before the M0 SSH contract re-scope is accepted (ADR-023). |
| `1tzaed` record-macos-release-identity-entitlement-and-migration-contract **<-** `24icoz` build-four-platform-relay-assets | the macOS release identity contract ratifies the measured relay bundle byte budget. |
| `2d3g5e` add-common-ssh-transport-conformance-tests **<-** `yx2fca` rescope-ssh-transport-contract-to-m0-viability | conformance tests bind to the re-scoped Tier-1 contract. |
| `3gkwn0` configure-developer-id-notary-and-macos-release-environment **<-** `dveo1o` establish-notarytool-keychain-credential-custody | the release environment cannot be configured before notarization custody is Keychain-only (ADR-025). |
| `3jloqy` provision-app-ids-capabilities-and-development-profiles **<-** `apc34w` verify-relux-works-apple-account-readiness | portal mutations need the verified account readiness record (replaces the reversed ypo7yo <- apc34w edge). |
| `3jloqy` provision-app-ids-capabilities-and-development-profiles **<-** `q5kjta` conduct-c1-apple-permission-ceremony | portal mutations use the authorization granted at C1 (ADR-028). |
| `apc34w` verify-relux-works-apple-account-readiness **<-** `q5kjta` conduct-c1-apple-permission-ceremony | account readiness is recorded with the portal session granted at C1 (ADR-028). |
| `z37ay7` enforce-udp-resource-limits-and-dns-priority **<-** `1pn983` record-memory-window-rekey-contract | UDP resource limits consume the memory/window/rekey contract (cycle repair, correct direction). |
| `a8uhro` add-self-update-integrity-signature-and-rollback-tests **<-** `3bj9bk` pin-sparkle-public-key-and-verify-appcast-signing | update-integrity tests require verified appcast signing. |
| `ziprhs` generate-and-install-sparkle-eddsa-update-signing-secret **<-** `q5kjta` conduct-c1-apple-permission-ceremony | the Sparkle key is generated at C1; this task records the public evidence (ADR-026, ADR-028). |
| `3bj9bk` pin-sparkle-public-key-and-verify-appcast-signing **<-** `1mt4e7` implement-signed-appcast-and-release-asset-generation | appcast sign/verify evidence needs the appcast pipeline. |
| `3bj9bk` pin-sparkle-public-key-and-verify-appcast-signing **<-** `xempiv` integrate-sparkle-updater-into-macos-app | public-key pinning needs the integrated updater, itself behind the generated macOS target. |
| `3bj9bk` pin-sparkle-public-key-and-verify-appcast-signing **<-** `ziprhs` generate-and-install-sparkle-eddsa-update-signing-secret | public-key pinning needs the generated key (ADR-026). |
| `3cveay` implement-deferred-m3-ssh-semantics-and-observability **<-** `1gjxer` record-m0-ssh-engine-selection | M3 Tier-2 delivery waits for the engine selection. |
| `3cveay` implement-deferred-m3-ssh-semantics-and-observability **<-** `3kimon` implement-channel-window-budget-policy | M3 Tier-2 delivery waits for the observability contract. |
| `3cveay` implement-deferred-m3-ssh-semantics-and-observability **<-** `yx2fca` rescope-ssh-transport-contract-to-m0-viability | M3 Tier-2 delivery is defined by the re-scoped contract, so the four deferred SSH semantics cannot be forgotten. |
| `dveo1o` establish-notarytool-keychain-credential-custody **<-** `apc34w` verify-relux-works-apple-account-readiness | notary custody needs the verified account readiness record. |
| `dveo1o` establish-notarytool-keychain-credential-custody **<-** `q5kjta` conduct-c1-apple-permission-ceremony | the notary profile is stored at C1; this task verifies it (ADR-025, ADR-028). |
| `q5kjta` conduct-c1-apple-permission-ceremony **<-** `ypo7yo` define-apple-identifier-and-entitlement-matrix | Ceremony C1 authorizes exactly what the approved identifier/entitlement matrix names (ADR-028). |

## Restored in round 3

| edge | why |
| --- | --- |
| `1u2vpc` run-libssh2-functional-and-rekey-matrix **<-** `2ayxqn` record-gate-p0-disposition | Round 2 removed it, which scheduled the libssh2 matrix before Gate P0 existed even though the matrix scope still requires a Gate-P0 provider smoke on the physical Apple-silicon Mac. Restored rather than re-scoped, so no Apple-target row is weakened. Review item 2. |

## Invariants re-checked against the full delta

No removed or added edge touches any of these; each remains enforced by a live blocker chain:

- host-key verification before user auth — `2d3g5e` keeps `yx2fca` and `39xz9g`; `1u2vpc` AC2 unchanged
- Keychain-only secrets — strengthened by ADR-025, `dveo1o`, and the new `3gkwn0 <- dveo1o` edge
- fail-closed DNS — `1fpr3u`/`zwtrhy` keep their macOS routing/leak blockers; `3f4rhy` -> `12x6oq` -> `2wqffe` intact
- bounded memory — `1pn983` keeps `2jatnd` and `1gjxer`; the cycle repair did not drop a memory gate
- public PacketFlow bridge — untouched; no bridge edge appears in the delta
- rootless exec/stdio relay — untouched; no relay-execution edge appears in the delta
- macOS provisioning / Gate P0 — `9yp8to <- 1r0fxv <- 3jloqy <- {apc34w, ypo7yo, q5kjta}` intact and `1u2vpc <- 2ayxqn` restored
- signed + notarized release — `3gkwn0 <- dveo1o`, `1njthi <- 3bj9bk`, `a8uhro <- 3bj9bk` all added, never removed

