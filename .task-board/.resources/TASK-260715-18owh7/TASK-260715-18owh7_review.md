# TASK-260715-18owh7 — Review record (reviewer, 2026-07-20)

Verdict: **ACCEPTED** → `done`. Accountable architecture approval per decision §8
is hereby recorded: Option A — fixed v1 schema constants + unilateral local caps,
zero new wire bytes, reserved compatible upgrade path (hello flag bit 1, feature
bit 1, message types `0x40–0x4F`).

## AC-by-AC verification

- **AC1 — conflict quoted, facts/assumptions separated.** PASS. Both quotes
  verified verbatim in-repo: `.spec/relay-protocol.md:110-113` ("Maximum frame,
  association count, queued bytes, datagram size, and idle timeout are
  negotiated/capped and included in diagnostics") and
  `.spec/security-privacy.md:59-66` (validate-before-socket, bounded memory).
  Facts F1–F9 checked; assumptions A1–A3 individually marked with M3
  measurement hooks; compatibility consequences derived in §2.3.
- **AC2 — four-option comparison.** PASS. §3 compares A (fixed constants +
  local caps), B (feature-gated post-hello LIMITS), C (hello extension), D
  (protocol v2) across old-peer behavior, safety, complexity, vectors, rollout.
  C's misparse mechanism (appended hello bytes consumed as garbage
  `frameLength`) is accurate against the frozen binding §4.2/§4.3. Rejections
  of C (v1-incompatible per binding §6) and D (version-locked greenfield pairs,
  F6/F7) are evidence-based, not convenience-based.
- **AC3 — exact contract.** PASS. §4.1 `maxFrame` u32 BE, hello offsets,
  default 4096, floor 2048, ceiling 65536, invalid-value behavior on both
  sides, min-rule lowering. §4.2 `maxUDPPayload = 1472` fixed wire constant
  with violation-vs-policy enforcement split. §4.3 six local caps with
  default/floor/hard-ceiling/breach-behavior each. §4.4 normative
  validation-before-socket order. §4.5 fail-closed startup on out-of-range
  config, no silent clamping. §4.6 `RelayEffectiveLimits` typed slot filled
  (field widths check out: 1472 < u16, 16:1 < u8, 600 000 ms < u32). §4.7
  diagnostics counters named. Gating: reserved bits/range verified genuinely
  unallocated in the frozen binding (types 0x10/0x11/0x20/0x21/0x30/0x31,
  flag/feature bit 0 only).
- **AC4 — no-misparse and hard-cap proofs.** PASS. M0 adds zero wire bytes, so
  there is nothing to misparse; reserved-name reception paths are the frozen
  deterministic rejections (reserved flag → status 0x0002; unnegotiated type →
  session-fatal). Only `maxFrame` crosses the wire and is clamped to the local
  hard cap before any body-sized allocation; every other limit is
  min(schema, local config) with no wire input; out-of-range config kills the
  process at startup. Deployment coupling (manifest-verified upload, F6) makes
  mixed-version pairs unreachable.
- **AC5 — approval + downstream by ID.** PASS. All 13 downstream tasks
  (2azda7, 1y1g1u, 89h7cw, 516lhy, 1jvgcn, 1q7u14, 297gq6, 2z9b4a, 22gz6h,
  xw5dxc, z37ay7, 3xpc6b, 3edgwz) verified to carry new TASK-ID-scoped notes
  with their exact slice of the contract. Direct block links unchanged and
  correct. Logbook entry 1554 present. ADR-021 number verified free (last is
  ADR-020).

## Independent fact verification

- HEV bound (F3/F4): `UDP_BUF_SIZE 1500` at
  `.temp/TASK-260715-uopycx/hev-socks5-tunnel/src/core/src/hev-socks5-udp.c:26`;
  `hev_socks5_udp_recvmmsg_tcp` returns `-1` (stream-fatal) when
  `udp.datlen > msgv[i].len - addrlen` with `addrlen = hdrlen - 3` (7 IPv4 /
  19 IPv6); `msgv[i].len = UDP_BUF_SIZE` in `hev_socks5_session_udp_fwd_b`
  (`hev-socks5-session-udp.c` fwd_b). Worst case `MSGLEN ≤ 1481`;
  1472 ≤ 1481 with 9-byte margin; reply write bound `19 + 1472 = 1491 ≤ 1500`
  holds by construction. Confirmed.
- Frame arithmetic: max legal v1 body `6 + 255 + 1472 = 1733` (HDRLEN u8 max
  `7 + 248 = 255` per binding §4.4) < floor 2048, so the "every accepted hello
  carries every legal frame" invariant holds. Confirmed.
- ADR-009/010/015/020 exist in `.spec/decisions.md` and say what F5/F8/§4.2
  claim; `packet-plane.md` confirms 25–30 MiB target and
  `max-session-count: 1200`.
- Artifacts: `diagrams/TASK-260715-18owh7_limit-enforcement-points.puml` +
  rendered SVG (real PlantUML sequence output, content matches §4.4) and
  `diagrams/TASK-260715-18owh7_limit-ownership.dot` (source authoritative;
  workstation `dot` broken since 111tde — pre-existing, not this task's debt).
- No product code modified (git status: board resources, diagrams, LOGBOOK.md
  only). "Tests green" is N/A for a decision record — nothing compiled; board
  `task-board validate` clean.

## Non-blocking observations (feed M3, no rework needed)

1. §6 lists STORY-260715-1zzt0c / STORY-260715-19ii11 as consumers but no
   board notes were added to those stories (their input is fully specified in
   decision §7 + §4.7 and the logbook, so nothing is lost).
2. The RFC 4787 REQ-5 claim holds for the relay's own timer, but the effective
   end-to-end mapping lifetime is min(client 60 s, relay 120 s) = 60 s. Real
   apps keepalive at 15–25 s and the decision already gates timers on G3, so
   this is a fine M0 baseline — G3 should evaluate the *effective* lifetime,
   not the relay timer alone.
3. The "unfragmented egress" arm of the 1472 derivation is IPv4 arithmetic
   (IPv6 egress bound would be 1452); the HEV bound is the load-bearing one
   and G1 covers reply-size evidence. No change needed.

## Handoff

- **Coordinator action required:** commit the ADR-021 row (drafted verbatim in
  decision §8) to `.spec/decisions.md`, per the same convention as the
  TASK-260715-111tde acceptance commit. Reviewer is read-only and does not
  commit.
- Unblocked on acceptance: TASK-260715-2azda7, TASK-260715-22gz6h,
  TASK-260715-xw5dxc, TASK-260715-z37ay7, TASK-260715-3edgwz.
