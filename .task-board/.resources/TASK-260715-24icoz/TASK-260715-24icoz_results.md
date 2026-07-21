# TASK-260715-24icoz — portable relay asset results and blocker evidence

Date: 2026-07-21
Role: developer
Disposition: blocked on external runtime fixtures and an explicit bundle budget

## Delivered implementation

- Added `scripts/relay_release.py inspect-assets` and the `make relay-portable-assets` entrypoint.
- The command requires a caller-supplied total `RELAY_BUNDLE_BUDGET_BYTES`; it has no policy default.
- Inspection accepts only the four canonical target directories and filenames and verifies regular nonempty executable mode, raw format and machine architecture, Go 1.26.5 target/CPU metadata, linkage, minimum runtime, dynamic libraries, stripped/no-DWARF disposition, size, SHA-256, and path/credential privacy.
- The stable JSON report records an over-budget measurement before returning failure.
- Added tests for ELF/Mach-O debug-section rejection, exact four-target layout, canonical names, budget arithmetic, path-free reporting, unexpected executables, and retained over-budget evidence.
- Updated `README.md` and `relay/README.md` with the required budget input, command, and output locations.

## Clean retained assets

Build inputs:

- source commit: `58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096`
- `SOURCE_DATE_EPOCH`: `1784656987`
- validation relay identity: `0.1.0` (evidence identity, not a new release-version policy)
- protocol: v1
- toolchain: official pinned Go 1.26.5, `gc`, internal linker, `CGO_ENABLED=0`
- mode: detached clean checkout, clean target workspaces, `--require-clean`, `-trimpath`, `-s -w`, empty build ID

| Target | Format / machine | Bytes | SHA-256 | Minimum runtime and linkage |
| --- | --- | ---: | --- | --- |
| `darwin/amd64` | Mach-O 64-bit / x86_64 | 2,623,664 | `783b94982e90f0ceed0af0fa11662d11a333e244b87256cbfa0f7d21695f3290` | macOS 12.0; `/usr/lib/libSystem.B.dylib`, `/usr/lib/libresolv.9.dylib` |
| `darwin/arm64` | Mach-O 64-bit / arm64 | 2,487,362 | `8ac45b257099c9d2079b0bd2cb9ae489acfb86e443ba7ca7e4b4b2a56380d64c` | macOS 12.0; `/usr/lib/libSystem.B.dylib`, `/usr/lib/libresolv.9.dylib` |
| `linux/amd64` | ELF64 little-endian / x86_64 | 2,592,894 | `ddcb22ed4d4a978992a04096abae8adc58d0b8bf3bcdc0c0a006775797e2941f` | Ubuntu 24.04 declared native fixture; static, no `PT_INTERP`/`PT_DYNAMIC`, no libc |
| `linux/arm64` | ELF64 little-endian / arm64 | 2,556,030 | `908b3d9ea3543b6144e2c99407c9aa02cc69e86c1cce80364d32dbdc3de8e0dc` | Ubuntu 24.04 arm64 declared native fixture; static, no `PT_INTERP`/`PT_DYNAMIC`, no libc |

Total executable bytes: **10,259,950**. All four are mode `0755`, contain no DWARF/debug sections or companion debug artifact, and passed the privacy scan. A deliberate one-byte negative budget exercised the real inspector and retained the exact 10,259,949-byte overage before failing; one byte is test input, not an approved budget.

Retained archive:

- `TASK-260715-24icoz_portable-relay-assets.tar.gz`
- SHA-256: `daf0e1927999a369b49744f821414d8b56fd551fb0bf757925758fa83d358834`
- exactly four regular executable members with normalized, non-host owner metadata and no absolute paths

## Runtime evidence

The retained staging bytes are byte-identical to the manifest-selected release build used by the existing identity/stdio smoke comparator.

| Target | Evidence |
| --- | --- |
| `darwin/arm64` | Native macOS execution as UID 502 passed canonical identity/self-hash, protocol-v1 stdio hello, zero diagnostics, and clean exit. |
| `darwin/amd64` | Rosetta 2 execution as UID 502 passed canonical identity/self-hash, protocol-v1 stdio hello, zero diagnostics, and clean exit. The accepted handoff still requires native Intel or explicit approval of this emulated baseline. |
| `linux/amd64` | Not executed. No native/approved local fixture exists. |
| `linux/arm64` | Not executed. No native/approved local fixture exists. |

The exact-commit GitHub Actions run `29855573312` contains zero executed steps. Check-run annotations for both native Linux jobs state: `The job was not started because recent account payments have failed or your spending limit needs to be increased.` This is an account-level external blocker, not a build/test failure.

## Verification run

- `make relay-toolchain-test`: 31 Python release tests passed (the final aggregate-ordering regression was rerun after the earlier 30-test aggregate gate).
- `make relay-shell-test relay-shell-vet`: all Go packages passed with pinned Go 1.26.5; `go vet` passed; the release test suite passed and was rerun at 31 tests after the ordering fix.
- `make relay-protocol-check`: 89 canonical vectors, Go conformance/hostile tests, 58 Swift protocol tests, generator drift gates, and `swift build` passed.
- Detached clean `make -j4 relay-toolchain-build-all ... RELAY_BUILD_CLEAN_FLAG=--require-clean`: exactly four assets built.
- Detached clean `relay-shell-release`, `relay-shell-verify`, and `relay-shell-smoke`: manifest/checksum/identity/stdio validation passed for native Darwin arm64 and Rosetta amd64; unavailable native rows remained explicit.
- `make relay-toolchain-ci`: tests, vet, exact missing-input gates, four clean-mode target builds, metadata/linkage, and licenses passed.
- Black check, `py_compile`, ShellCheck 0.11.0, Actionlint, `git diff --check`, targeted privacy scan, and `task-board validate` passed.

## Exact unblock inputs

1. The bundle owner must provide or approve the total bundle budget in bytes. Recommendation: decide it against the measured 10,259,950 executable bytes plus separately owned manifest/notices/signing overhead; do not derive policy from the measurement itself.
2. Restore GitHub Actions billing/spending (or provide another approved native Ubuntu 24.04 fixture) and run both Linux target rows against these exact hashes.
3. Provide native Intel macOS execution, or explicitly approve Rosetta 2 as the accepted `darwin/amd64` emulated baseline for this acceptance criterion.

Until those inputs exist, AC3 and AC4 remain unsatisfied and review handoff would be misleading.
