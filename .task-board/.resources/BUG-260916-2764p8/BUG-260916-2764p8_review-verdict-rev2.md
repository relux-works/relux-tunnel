# Independent review: accepted revision 2

Reviewer RUN-260916-f3ce0f. No code changes, commits, branch/ref changes, publication, installs, VPN operations, or root LOGBOOK writes. Scratch-only alternate index composition; active cache preserved.

## Exact identity and scope

Reviewed base b3422b05226253a17676b9b84c764071fe3dbe74 and candidate tree 766824884cac85078199779dbe9c67c9bcbf1be9. Patch SHA256 independently matches 36d2915ac3e26f90195e272e744dadb9eef18104a8d9b52ca39eaca5c32065d5. Worktree HEAD remains the base and product bytes match candidate.

Fresh `git ls-remote origin refs/pull/6/head` reports 310a560916d8b8012fa238f65b51649041caee4d. Exact-object fetch with --no-write-fetch-head succeeded. `git verify-commit` succeeded: good git signature for oparin@me.com, ECDSA SHA256:V6JiKG7J29mjsvikcLoSVp0bLa77VTsFy12gnLO81cM.

58 of 59 changed paths have identical PR6/candidate blobs; the remaining file equals the PR6 blob after exactly one replacement: `weak let weakHostOwner = hostOwner` to `weak var weakHostOwner = hostOwner` at Sources/ReluxTunnelHarnessSupport/M1RuntimeCommand.swift:138. All non-board tree entries were compared; this is the only product difference. Pre/post blobs: bcd896110682117e347fda955c9024e71297e9cf / d868eb7be3849c8aa0da84a0423de6c5476ebb38. Checkout .task-board differences are not product scope; control-root board is authoritative.

Prospective composition built with a scratch GIT_INDEX_FILE from exact PR6 head plus only the fixed blob: **c8d2b249b9bf8875b2309320c70b64e0e3e12ac5**. Independently asserted its only changed tree entry is M1RuntimeCommand.swift. Every other PR entry, including board bytes, fixtures and previous fixes, is preserved. Do not publish the managed candidate tree wholesale.

## Semantics and evidence

The weak optional still observes owner release after `hostOwner = nil`; the nil guard, providerFailure stop, hostLifetimeInvariant throw, runtime lifecycle and cancellation paths remain identical. This is a minimal declaration compatibility correction. Existing committed tests suffice; no new behavior or gate is introduced.

Independently reran `env -u SDKROOT swift test --filter 'M1RuntimeHarnessTests|MacOSProductionRuntimeOwnership|M1RuntimeComposition|DeterministicSessionFactory'`: exit 0, 20 tests in 4 suites. `git diff --check` on product delta: exit 0. macOS harness is the relevant target for this repair despite package iOS support. Full real package composition, no mock replacement package.

Reused unchanged full managed revision-2 validation resource BUG-260916-2764p8_change-request_rev2-validation.log: credential-free generated-project gate exit 0, 1 of 1 exact command shards green; test-case coverage unknown. It includes Swift testing/release build, macOS target contracts, negative guard tests and preservation checks. This was read, not rerun by reviewer. Producer evidence additionally records 7/7 real-binary fixtures and pre-fix compilation on local compiler.

Inspected producer raw mutant command/result: replacing weak storage with strong storage leaves lifetime guard present; M1RuntimeHarnessTests fails with 14 issues, output EXIT:1, including productionEntryDoesNotRetainOrConsultHostOwner at line 80. The enclosing logging command itself returns 0; it must not be reported as the test exit. Restored candidate passes independent rerun. This is ownership fault injection, NOT a narrowing mutant of the lifetime guard. No guard or source-text checker changed in this bug, so no newly shipped gate requires a new narrowing mutant. Existing prerequisite negative suites are reused, not claimed as a fresh exhaustive gate audit.

## Corrected coverage and bounds

**2 of 4 AC rows driven by named committed executable tests**, using producer's four-row decomposition; 2 process-evidence rows are non-executable bounds, not test coverage:
1. Weak lifetime: successfulComposedGenerations and productionEntryDoesNotRetainOrConsultHostOwner drive HarnessApplication.run -> M1RuntimeHarnessCommand.run, release/nil guard and post-release traffic.
2. Runtime ownership: MacOSProductionRuntimeOwnershipTests.exactGraphLifecycle drives MacOSProductionDependencyFactory.makeRuntime and returned runtime start/stop; M1RuntimeCompositionTests.productionGraphPerGeneration drives factory.makeRuntime(context:). Cleanup/health failure assertions remain green.
3. Focused validation/toolchain reporting: command logs and environment evidence, not an executable AC test.
4. Prerequisite/delta reviewability: Git object comparison and scratch composition evidence, not an executable AC test.

Local Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), Xcode 26.5 build 17F42, SDK macOS 26.5, arm64 host. Initial ambient `xcrun --show-sdk-version` failed due to SDKROOT pointing to missing CommandLineTools SDK; explicit env -u SDKROOT lookup succeeded and was used for rerun. No persistent environment modification. Local compiler accepts weak let; this review does not reproduce hosted diagnostic. Known WeakMutability warning on weak var is the compatibility tradeoff; do not describe compiler output as warning-free. No separate configured lint gate was added.

Hosted run35087910852 has no precise compiler version in supplied evidence. Neither Swift6.1-tools package manifest nor macos-15 runner proves the actual compiler version. Producer's older-toolchain/unique-spelling assertions are not established hosted proof. Hosted compilation of the eventual signed head remains a subsequent delivery gate.

## Verdict

Accept revision 2 for composition on the exact input head above. No blocking product findings. This acceptance does not approve a future signed commit, assert hosted CI green, or authorize bypass of actual platform review/landing checks. Parent owns subsequent delivery. Review findings and reporting corrections are recorded here instead of changing root LOGBOOK. Changes-requested branch is not applicable.
