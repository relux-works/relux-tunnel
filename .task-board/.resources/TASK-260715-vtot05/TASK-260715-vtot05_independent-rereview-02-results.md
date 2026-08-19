# TASK-260715-vtot05 independent re-review 02 results

Date: 2026-08-19
Verdict: changes requested
Route: to-dev

## Material finding

The runtime no-download audit remains fail-open, so AC5 and the independent re-review contract are not satisfied. The blacklist in scripts/relay_supply_chain.py lines 105-126 and scanner at lines 908-955 accept ordinary application download and process surfaces that the documentation and LOGBOOK claim are rejected.

An independent temporary-fixture probe exited 0 but reported ACCEPTED for all eleven invalid cases:

- Swift Foundation String(contentsOf: remoteURL)
- Objective-C NSData dataWithContentsOfURL
- C and C++ curl_easy_init plus curl_easy_perform
- C system(command), popen(command), and posix_spawn
- Go aliased imports web net/http plus web.Get and runner os/exec plus runner.Command
- newly introduced .cxx and .hpp source entries containing libcurl calls; they are outside the fixed extension set and are silently skipped when another safe file makes the scan non-empty

These are representative Swift, Objective-C, C, C++, Go, process, download, and newly introduced source-entry cases explicitly required by the rereview contract. This is not merely a semantic completeness objection: current project documentation says Foundation loaders, process or shell execution, Go HTTP or process surfaces, and relevant C/C++ source kinds fail closed, which these reproductions disprove.

Minimal remediation: extend the immutable source-kind set to the project-relevant C/C++ variants including .cxx, .hpp, .hh, and .hxx; reject Foundation String and Objective-C URL-loading selectors; reject libcurl and C-family process entry points such as system, popen, posix_spawn, and exec variants; parse or match Go imports independently of aliases; add one negative test per reproduced case. Keep the claim explicitly bounded and update the LOGBOOK wording if any surface remains intentionally outside the gate.

## Prior finding reproduction

The rework correctly rejects every previous material fail-open case for the correct reason:

- lockstep content-hash mutations for relay source, build recipe, Go compiler/linker, and Go standard library all reject as authoritative provenance mismatches;
- alternate plausible SPDX/text mappings reject as approved-license mapping mismatches;
- branch, tag, query, fragment, percent-encoded path, host-case, and doubled-path URL variants reject against exact immutable allowlists;
- empty, partial, and reordered runtime roots/extensions reject;
- symlinked scope entries reject.

## Positive evidence and exit codes

- make relay-supply-chain-audit relay-supply-chain-test relay-asset-manifest-test: exit 0; audit, 16 supply-chain tests, 26 asset tests, and 4 Swift Testing tests passed.
- make relay-shell-test relay-shell-vet: exit 0; all Go packages, 35 release tests, and vet passed offline with pinned Go 1.26.5.
- swift build: exit 0; unsigned build passed.
- Black check, Swift format lint, Actionlint, in-memory Python compilation, JSON parsing, generated privacy scan, and git diff --check: combined exit 0.
- Independent double render: exit 0; all five outputs were identical between runs and matched checked-in bytes. Hashes: inventory 434c541234e46f207e1b67fc57dceecb324bebcc2bd25f403c4159def4df0616; provenance f5b1170f9fd0995ab931c97178768559a74d150fb5fce711de07b51793b37d2c; notices 7f1edb1216363e034bd06b4d41edfd04958a597b0dad8ae3cdd4e7c91c69006f; asset source d5b861fa755f119b0b743db33426b3b099b282585d88900896ebd9b3c028ef92; Swift catalog 71d26dec9415594b26903b72378efdb953e57ebc957687dbb7f712bf1f632820.
- Manifest linkage 61dbd903ce1055f852a52718adb887d9d5acafb78a6758fae3d0f02a0db9061a is consistent across inventory, provenance, asset source, schema-driven manifest, and Swift output. Product notices exactly cover the two distributed components.
- Pinned Go reports go1.26.5 darwin/arm64; its LICENSE hash is 911f8f5782931320f5b8d1160a76365b83aea6447ee6c04fa6d5591467db9dad. Independent go list resolves buildinfo.go, identity.go, codec.go, generated_v1.go, handshake.go, session.go twice in distinct packages, and main.go, matching the eight compiled Go files plus relay/go.mod in provenance.
- Makefile and CI integration are present and lint clean. The M2/M5 boundary assigns the four required M2 controls and concrete downstream M5 signing, notarization, release-attestation, and distribution tasks.
- task-board validate: exit 0 while reporting one PARENT_STATUS_MISMATCH for EPIC-260715-2lz67t stored to-dev versus child aggregate reviewing. Scoped board evidence confirms unfinished epic blockers; validation was not weakened and this is separate from the rejection.

## Safety

No signing, notarization, attestation, publishing, credential or Keychain access, app/provider installation or launch, VPN mutation, startVPNTunnel call, route/interface/pf/DNS change, network fetch, or physical VPN validation was performed.