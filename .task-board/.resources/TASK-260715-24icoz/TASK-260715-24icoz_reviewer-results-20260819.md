# TASK-260715-24icoz reviewer verdict — 2026-08-19

Verdict: changes requested. Route to `to-dev`.

## Blocking finding

The retained archive SHA-256 is `daf0e1927999a369b49744f821414d8b56fd551fb0bf757925758fa83d358834`, but direct Python `tarfile` inspection finds **eight** regular executable members, not exactly four. In addition to the four intended binaries, it contains four 163-byte mode-0755 AppleDouble members: `darwin-amd64/._relux-relay-darwin-amd64`, `darwin-arm64/._relux-relay-darwin-arm64`, `linux-amd64/._relux-relay-linux-amd64`, and `linux-arm64/._relux-relay-linux-arm64`. Each intended binary also carries PAX keys `LIBARCHIVE.xattr.com.apple.provenance` and `SCHILY.xattr.com.apple.provenance`, plus fractional non-normalized mtimes. Extraction restores `com.apple.provenance` extended attributes. This contradicts the attached tester outcome statement that the archive contains exactly four regular executable members and fails the fresh-review exact four-member contract, AC1, and AC5 archive hygiene/undeclared metadata requirements. Strict archive check exit: 1. Metadata diagnostic exit: 0.

Required rework: recreate and reattach the retained archive with exactly the four canonical executable members, normalized deterministic ownership/mode/mtime, no AppleDouble members, no PAX/xattr metadata, and an updated SHA/evidence report. Add a regression test that opens the final tar stream and asserts the exact member-name set/count, regular-file type, 0755 mode, root ownership, normalized mtime, empty PAX headers, expected sizes/hashes, and absence of `._*` members.

## Passing evidence

- The four intended executable bytes independently pass format/machine, CPU baseline, minimum runtime/linkage, executable mode, stripped/no-DWARF, Go 1.26.5 build metadata, sizes, and recorded SHA-256 checks; direct inspection exit 0. Total intended executable size is 10,259,950 bytes and remains handed to TASK-260715-1tzaed.
- Rootless UID 502 native darwin/arm64 identity + protocol-v1 stdio + clean exit: 0. Approved Rosetta darwin/amd64 identity + protocol-v1 stdio + clean exit: 0. Linux amd64, Linux arm64, and native-Intel execution remain explicitly deferred to TASK-260715-1c4l9v, not passed.
- Retained inspector invoked with source commit `58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096` from current HEAD exits 1 with `source commit does not match checkout HEAD`; direct retained-byte inspection was kept separate and did not turn provenance mismatch into a pass.
- New truncated/wrong-architecture tests exercise the real ELF/Mach-O parser entry points and pass. `make relay-toolchain-test relay-shell-test relay-shell-vet`: exit 0; 33/33 release tests plus all Go tests/vet pass. Affected inspection coverage: 243/301 executable lines, 80.7%, exit 0. Black, Python compile, ShellCheck, Actionlint, and `git diff --check`: exit 0.
- Fresh current-HEAD four-target clean-cache build and `inspect-assets`: exit 0, four canonical executable files, 10,259,950 total bytes. This does not repair or replace the malformed retained archive.
