# TASK-260715-3bdplx — Review of the relay toolchain decision

Date: 2026-07-20
Reviewer: [reviewer] reviewer (claude)
Artifact under review: `TASK-260715-3bdplx_relay-toolchain-decision.md`
(identical project copy: `.research/260720_task-260715-3bdplx-relay-language-cross-build-toolchain.md`)

## Verdict

**Accepted → done.** All five acceptance criteria are satisfied. The decision is
exact, evidence-bounded, and fits the project architecture. Dependent tasks
`TASK-260715-1ccx3l`, `TASK-260715-1g9cyt`, and the M2 relay build can start
with no open language or tooling question.

## Independent verification performed

All checks below were re-executed by the reviewer, not taken from the analyst's
report.

### Proof binaries and reproducibility

- `.temp/TASK-260715-3bdplx/go1265-a` and `go1265-b` each contain the four
  assets; every pair compared byte-identical (`cmp`), confirming the
  two-clean-tree reproducibility claim.
- All four SHA-256 hashes and byte sizes match the decision document's proof
  table exactly (`c81ff905…`, `71ea84d0…`, `69f250d5…`, `1bd29079…`;
  2,030,192 / 1,967,666 / 1,953,918 / 1,900,670 bytes).
- `file`: both Linux outputs are `ELF 64-bit LSB executable … statically
  linked, stripped`; both Darwin outputs are Mach-O for the correct CPU.
- `otool -L`: Darwin binaries link exactly `/usr/lib/libSystem.B.dylib` and
  `/usr/lib/libresolv.9.dylib`, nothing else. `otool -l` shows
  `LC_BUILD_VERSION minos 12.0` on both, confirming the macOS 12 floor.
- `go version -m`: every inspected binary embeds `go1.26.5`, `CGO_ENABLED=0`,
  the correct `GOOS`/`GOARCH`, `GOAMD64=v1` or `GOARM64=v8.0`, and
  `-trimpath=true`.
- Runtime re-run by reviewer: `echo hello | relux-relay-darwin-arm64` printed
  `stdio:hello` / `udp:ok` natively; the amd64 binary did the same under
  Rosetta 2. Both exit 0.

### External fact-check (live sources)

- Go 1.26.5 archive checksums: fetched `https://go.dev/dl/?mode=json` — all
  four SHA-256 values in the decision match go.dev exactly.
- Syft: local `syft_1.48.0_darwin_arm64.tar.gz` SHA-256
  `fef3e6d5…` matches both the decision and the official
  `syft_1.48.0_checksums.txt`; the extracted binary reports version 1.48.0,
  commit `3e2bc6ed095f7ec1a415fb38cfe1c319e95dfed6` — exactly as pinned.
- SBOMs: all four `.spdx.json` files are SPDX-2.3 and contain
  `stdlib@go1.26.5` with `licenseDeclared: BSD-3-Clause` plus the binary
  package with the matching `sha256:` — the document's SBOM claims are accurate.
- Go wiki MinimumRequirements confirms the Linux kernel 3.2 general floor; the
  product's chosen 4.4 floor is strictly conservative above it.

### Acceptance criteria

1. **Comparison** — Go, Swift, Rust, and C17 are each evaluated against
   portability, binary size, memory, build reproducibility, testing, security/
   supply-chain, and maintenance, with a scored matrix and per-candidate
   rationale. Met.
2. **Exactness** — language (Go 1.26), compiler (`go1.26.5` gc,
   `CGO_ENABLED=0`), dependency policy (stdlib-only, vendoring rules for any
   future dependency), Go target pairs plus canonical triples, output names,
   `relux-relay-manifest-v1.json` schema, and `SHA256SUMS` format are all
   explicit. Syft 1.48.0 and govulncheck v1.6.0 are pinned. Met.
3. **Proof** — all four required OS/arch targets were actually cross-built and
   verified (see above); Darwin arm64 ran natively, Darwin amd64 under
   Rosetta 2. Native Linux and Intel-hardware execution are honestly bounded as
   release stop-line CI gates backed by official Go platform support — this is
   the "equivalent primary evidence" branch of the AC, and no unverified
   support is claimed. Per the task inputs, stop-the-line applies to a
   cross-build gap; there is none. Met.
4. **Tradeoffs** — rejected options recorded with concrete reasons; static
   linking feasibility is explicit (Linux fully static without any libc, Darwin
   near-static) and remaining runtime dependencies are named. The Go GC
   soft-limit tradeoff is stated honestly with a 32 MiB RSS gate and a defined
   Rust re-evaluation trigger instead of a hidden tuning fallback. Met.
5. **Handoff** — 1ccx3l gets the uname mappings, output names, and manifest
   verification flow; 1g9cyt gets the isolated `relay/` module, pins, and
   Makefile boundaries; no Swift/Go FFI seam. Met.

### Architecture fit

- ADR-005/ADR-006: rootless exec/stdio relay, upload via exec stdin, no SFTP —
  the decision assumes exactly this shape.
- `security-privacy.md` relay supply chain: pinned source revisions, manifest
  with protocol version/platform/size/SHA-256 per asset, versioned handshake
  and build identity (ldflags-embedded Version/Commit) — all covered.
- `platform-distribution.md` pipelines 4–5: reproducible relay cross-build
  matrix, checksums, manifest generation, SBOM — directly implemented by the
  contract.
- Unsigned individual relay binaries with integrity via the signed app bundle
  plus manifest verification is consistent with the specs, and the document
  explicitly flags detached signing as a future decision if distribution
  changes.

## Non-blocking observations

- `.temp/TASK-260715-3bdplx/` also contains a first-pass build tree
  (`build-a`/`build-b`, from the initial Go 1.25.5 run) and a stray
  `syft_1.44.0_darwin_arm64.tar.gz`. The decision document only cites the
  go1265 numbers and the logbook records the 1.25.5 anomaly, so this is scratch
  residue only; `.temp/` is gitignored. No action required.
- The exit-host OS floors (Linux 4.4+, macOS 12+) are introduced by this
  decision rather than a prior spec; the spec update belongs to the dependent
  platform/distribution work when the relay matrix lands.

## Result

Checklist items "Implementation matches AC", "Solution fits project
architecture", and "Tests green" are satisfied; status set to `done`.
