## Status
done

## Assigned To
[reviewer] reviewer (claude)

## Created
2026-07-15T01:01:34Z

## Last Update
2026-07-19T23:50:09Z

## Blocked By
- (none)

## Blocks
- TASK-260715-p89bdj
- TASK-260715-1vv52g

## Checklist
- [x] Exact HEV, core, task-system, and lwIP revisions and hashes are pinned
- [x] Descriptor, framing, configuration, lifecycle, and license claims are source-backed
- [x] The manifest and notice audit are attached as TASK-ID-scoped outcomes
- [x] Findings written to file
- [x] Key aspects highlighted
- [x] Fact-checking performed — claims verified, sources cited
- [x] Findings linked on the board as a new task-scoped outcome resource
- [x] All questions from task description answered
- [x] Important findings, decisions, anomalies, or regressions recorded in logbook when relevant
- [x] Implementation matches AC
- [x] Solution fits project architecture
- [x] Tests green
- [ ] If review does not accept the work — verdict evidence added and status routed by the explicit verdict branches

## Notes
spawn queued: [analyst] researcher (codex) (run=RUN-260719-4a3b42, max_parallel=1)
spawn run started: [analyst] researcher (codex) (run=RUN-260719-4a3b42)
Logbook 2026-07-20: Pinned unmodified upstream hev-socks5-tunnel ad7600497931205105b08367bd1b450048157e40 with core c234519072ff5b928b90b304da9a666bcb440455, task-system b1afa0e21fb4ed5a69560e78e54baf0efdebe171, HEV lwIP 2a11c14c7a32887af25a034e82ef18b0b12076ac, and yaml efa36117a8646d26d12b58e05bac472d7854a70d. Apple XCFramework build passed. Critical anomaly: the advertised 24576 stack with tcp-buffer 4096 is raised to 35480 while udp-copy-buffer-num remains 10 because the parser minimum is 20480 + max(tcp_buffer, 1500 * udp_copy_buffer_num). Other integration constraints: single global/non-reentrant state, process-wide SIGPIPE ignore, lazy resolver pthread, caller-owned external tun_fd, Darwin 4-byte family header not validated on ingress, and quit must be issued only after startup then joined before descriptor close. Open upstream issue #315 remains relevant to rare teardown aborts; PR #299 stack reduction was not merged. Default is the exact unmodified graph; any callback/fork work requires Instruments evidence, a minimal diff, ABI/behavior tests, license/provenance updates, and re-audit. Outcomes: TASK-260715-uopycx_pinned-baseline-audit.md, TASK-260715-uopycx_dependency-manifest.json, TASK-260715-uopycx_third-party-notices.txt, TASK-260715-uopycx_build-apple-ad760.log.
agent completed: [analyst] researcher (codex) (exit=0)
spawn run completed: codex (run=RUN-260719-4a3b42, pid=21457, exit=0)
spawn queued: [reviewer] reviewer (claude) (run=RUN-260719-61cbcf, max_parallel=1)
spawn run started: [reviewer] reviewer (claude) (run=RUN-260719-61cbcf)
REVIEW VERDICT 2026-07-20: ACCEPTED. Independent reviewer fact-check against the retained pinned checkout (.temp/TASK-260715-uopycx/hev-socks5-tunnel): root ad7600497931205105b08367bd1b450048157e40 and all four submodule revisions (core c234519, task-system b1afa0e, lwip 2a11c14, yaml efa3611) reproduce exactly; deterministic git-archive SHA-256 for root and core re-derived and match the manifest; build log SHA-256 matches; board resource copies are byte-identical to .research versions. Source claims re-verified line-by-line: Darwin 4-byte family word read/write and absent ingress validation (src/hev-tunnel-macos.h), config defaults 8500/86016/65536/524288/10 and TCP_SND_BUF clamp 8*8191=65528 plus min-stack 20480+max(tcp_buf,1500*udp_copy_nums)=35480 anomaly (src/hev-config.c:441-452, src/hev-config-const.h), case-insensitive udp parse fallthrough-to-TCP (hev-config.c:251), CMD_FWD_UDP=5 for UDP_IN_TCP (core proto/client), relay frame datlen=htons(payload) + hdrlen=3+addrlen (core hev-socks5-udp.c:81-82), external-fd FIONBIO/no-close ownership (tunnel_init/tunnel_fini), file-static single-instance state, quit 100ms init-poll (hev-socks5-tunnel.c:702-708), SIGPIPE SIG_IGN (line 645). Licenses: 4x identical MIT Copyright (c) 2022 hev + lwIP SICS 2001-2002 confirmed against pinned files; notices sample faithful. XCFramework slices confirmed via lipo. Issue snapshot (#315 open, #301 open, #297/#298 closed) matches .temp/TASK-260715-uopycx/issues.json. All 5 AC satisfied; unmodified-upstream default + fork evidence gate declared. Tests green = pinned Apple build pass (research task, no project code changed). No discrepancies found. Routed to done.
agent completed: [reviewer] reviewer (claude) (exit=0)
spawn run completed: claude (run=RUN-260719-61cbcf, pid=15222, exit=0)

## Precondition Resources
- [TASK-260715-uopycx_audit-scope.md](file://TASK-260715-uopycx/TASK-260715-uopycx_audit-scope.md) — HEV/lwIP audit scope

## Outcome Resources
- [TASK-260715-uopycx_spawn-log_-analyst--researcher--codex-.log](file://TASK-260715-uopycx/TASK-260715-uopycx_spawn-log_-analyst--researcher--codex-.log) — System spawn log captured by task-board
- [TASK-260715-uopycx_pinned-baseline-audit.md](file://TASK-260715-uopycx/TASK-260715-uopycx_pinned-baseline-audit.md) — Pinned HEV/lwIP baseline research and source-backed findings
- [TASK-260715-uopycx_dependency-manifest.json](file://TASK-260715-uopycx/TASK-260715-uopycx_dependency-manifest.json) — Pinned dependency graph, source hashes, Apple flags, slices, and inspected paths
- [TASK-260715-uopycx_third-party-notices.txt](file://TASK-260715-uopycx/TASK-260715-uopycx_third-party-notices.txt) — License obligations and sample binary-distribution notices from pinned sources
- [TASK-260715-uopycx_build-apple-ad760.log](file://TASK-260715-uopycx/TASK-260715-uopycx_build-apple-ad760.log) — Successful pinned Apple XCFramework build evidence
- [TASK-260715-uopycx_spawn-log_-reviewer--reviewer--claude-.log](file://TASK-260715-uopycx/TASK-260715-uopycx_spawn-log_-reviewer--reviewer--claude-.log) — System spawn log captured by task-board
