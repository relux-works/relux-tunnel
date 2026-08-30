# TASK-260720-1qhxqa — M0 production binding manifest

Status: ready for independent review
Machine authority: `Configuration/TASK-260720-1qhxqa_m0-production-bindings-v1.json`
Validator: `scripts/validate-m0-production-bindings.py`

## Permit

`productionCompositionPermitted=true` only after the validator independently
recomputes every accepted outcome and reviewer-verdict SHA-256, confirms all
four authority tasks remain reviewer-terminal `done`, verifies the exact
resources are still declared, confirms every supersession marker is `current`,
recognizes the exact schema and all eight
stable compatibility rows, and verifies the checked-in provider graph and
native pins. Protected Swift target arrays are normalized and compared as exact
direct dependency/resource closures; missing, duplicate, extra, or unknown
expressions refuse composition. A lexical Swift source pass excludes comments
and string contents from target resolution and rejects duplicate or ambiguous
real target declarations. Manifest and board-state parsing reject duplicate
JSON keys so conflicting consumers cannot silently select different values.
It also verifies a pinned canonical digest covering
every exact accepted outcome/verdict SHA-256, normalized identity, pin,
capability, nested binding, obligation, trigger, compatibility condition, and
consumer constraint. The stored boolean is an attestation to recompute, not authority
that can override a failed row.

The upstream reviewer evidence records acceptance dates, not times of day. The
manifest preserves the exact ISO dates with `timestampPrecision=date`; it does
not invent midnight timestamps.

| M0 authority | Exact accepted outcome | Reviewer verdict | Accepted | Outcome SHA-256 | Supersession |
| --- | --- | --- | --- | --- | --- |
| `TASK-260715-nphtib` | `TASK-260715-nphtib_results.md` | `TASK-260715-nphtib_final-delta-review-results.md` | 2026-08-19 (date precision) | `63faf7a35b1c3554bbe5c23def6edddb9bc8454d40bfc1fb94071e1461f23ddd` | current |
| `TASK-260715-2jatnd` | `TASK-260715-2jatnd_m0-bridge-hev-decision-adr.md` | `TASK-260715-2jatnd_review-verdict-rev2.md` | 2026-08-29 (date precision) | `f2dc587541386cdc5eb7e10328adda21b8bbba3af32d5c722e62616a2abca173` | current |
| `TASK-260715-1gjxer` | `TASK-260715-1gjxer_ssh-engine-selection-adr.md` | `TASK-260715-1gjxer_results.md` | 2026-08-18 (date precision) | `f1d2369a694c7a6f6642cff4324b46a6727b7a6aef3d65a9cf13ee8821ea2282` | current |

The compatible runtime authority is
`TASK-260715-30zng6_runtime-contract.md` at SHA-256
`c13bbb54a455da89f3e66121c81532b298eab73fac30b6d14d2e2df43fff8851`,
accepted by `TASK-260715-30zng6_review.md` at SHA-256
`7a64ad098efd8cff52e0c6d144763b29e4d4008aab8e0967ce805c6134b0b756`.

## Normalized bindings

Generated graph:

- macOS production only; iOS production targets remain deferred;
- `ReluxProxyMacTunnel` directly consumes `ReluxTunnelMacOSAdapter` and the
  verified relay resource;
- `ReluxTunnelMacOSAdapter` consumes exactly Core, the selected libssh2 adapter,
  and the native adapter;
- Core remains candidate-neutral; HEV and selected-engine types stay in adapter
  modules;
- accepted repository revision is
  `069e23bdbbef71be194762d275b003a40a6cfc72`; accepted graph revision is
  `7dc73ac6e7325f86a4a178a0558619f0fc9d1490`.

Packet/HEV:

- unmodified five-revision HEV/lwIP graph plus the exact 16-file XCFramework
  path/SHA-256 lock recorded in the machine manifest;
- `AF_UNIX/SOCK_DGRAM` PacketFlowBridge; HEV borrows the retained peer;
- MTU 1500; requested send/receive buffers 32768 bytes with mandatory effective
  readback; 64 packets or 5 ms per pump slice;
- HEV stack/TCP/UDP-copy/session values 24576/4096/2/500;
- incremental HEV/bridge worst case 9,715,712 bytes at 500 sessions; the
  whole-extension budget remains blocked and cannot be inferred;
- HEV fork rejected. MTU 8500, unproved MTU 4096, 1200 sessions, physical iOS,
  NAT64, sleep/wake, whole-extension memory, and global pressure are not
  promoted.

SSH:

- selected `ReluxTunnelLibSSH2Adapter` with libssh2
  `a34302491c164d53c900fec9b3cbb050ecebe719`, OpenSSL 3.5.7, and exact
  archive/patch/header hashes in the machine manifest;
- exact libssh2 `COPYING`, OpenSSL license and acknowledgements digests plus
  retained ReluxNIOSSH patch and license digests are copied from the accepted
  ADR; their mutation or removal changes the independently pinned normalized
  contract;
- the retained ReluxNIOSSH patch disposition is additionally bound to the exact
  148-file checked-in fork tree by the deterministic
  `relux.sorted-path-file-sha256/1` digest (sorted relative path plus file
  SHA-256 records, excluding only `.build` and `.swiftpm`); any missing, extra,
  narrowed, or otherwise changed retained source byte blocks composition;
- primary algorithms are curve25519-sha256 / ssh-ed25519 / aes256-ctr /
  hmac-sha2-256; fallback is group14-sha256 / P-256 / aes128-ctr /
  hmac-sha2-512;
- receive window 32–64 KiB (accepted M0 value 64 KiB), transport/read/queued
  write/write-call bounds 64/16/32/8 KiB, and 64 pending operations;
- rekey envelope is 4 KiB–5 GiB per direction, 100 ms–1 hour, with exactly a
  10-second M0 completion timeout;
- one serialized session owner performs lifecycle and cleanup. ReluxNIOSSH is
  frozen comparative evidence and is not authorized for further fork work
  unless ADR-014 reopens.

Every license, notice, advisory-monitoring, patch ceiling, maintenance owner,
and revalidation trigger is copied as a normalized machine field. Deferred
values remain explicit; they are never converted into defaults.

## Fail-closed validation and consumer

Run from the repository root:

```bash
make m0-bindings-check TASK_BOARD_RESOURCES="$TASK_BOARD_DIR/.resources"
make m0-bindings-test
```

The Make target captures a compact authoritative board-state projection, then
the check emits a deterministic JSON report. Missing evidence is reported as
missing; malformed or unreadable input is reported as unknown/malformed. A
reopened authority or removed declaration is stale board state. Every failure
returns exit 1 and `productionCompositionPermitted=false`.

`TASK-260715-3ejhyy` must use the JSON manifest as its sole M0 binding source.
Its future macOS production factory entry point must run this validation before
constructing concrete SSH, PacketFlowBridge, or HEV dependencies and before any
`NetworkSettingsApplier.apply`. It must not duplicate values from the ADRs,
notes, source defaults, or this explanatory document.

## Negative evidence

The production CLI entry point is tested against changed bytes, missing
evidence, malformed JSON, duplicate manifest and board-state keys,
supersession, unknown fields/schema, a narrowed
two-of-three gate, changed normalized numeric values, weakened notice
obligations and compatibility conditions, negative/missing compatibility rows,
checked-in graph drift, an extra direct dependency in each of the provider,
macOS adapter, native adapter, and selected SSH adapter closures, and a duplicate
provider dependency. Actual HEV artifact byte drift, lock drift, and missing or
extra HEV files are independently refused at `REPOSITORY-HEV-PIN`. The selected
libssh2 patch digest, every required-slice
public-header digest, and the corresponding checked-in patch/header bytes are
also verified; missing, malformed, duplicate, or inconsistent SSH pin records
fail with `REPOSITORY-SSH-PIN`. The checked-in selected-license pins and
retained ReluxNIOSSH commit/archive/license pins are validated against the same
machine fields. The exact retained ReluxNIOSSH file set and bytes are also
validated, including the reviewer narrowing attack against
`Sources/NIOSSH/ReluxPolicies.swift`. Commented and multiline-string target decoys plus
duplicate real target declarations are also refused. Each attack must exit 1 with
permission false; the changed-resource tests prove an upstream replacement
cannot retain permission either under the old digest or after synchronizing the
mutable manifest digest to the changed bytes.
