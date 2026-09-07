# TASK-260715-3ejhyy — review verdict

## Verdict

**Accepted** for `CR-TASK-260715-3ejhyy-3` revision 3.

Reviewed the exact repository delta from base
`2f0d30c1369fd2440173f8537d8d6b2ec232c075` to candidate tree
`7c91cd2d8ecc986af1ca7bfc4a16a9b4c46070c3`. All eleven changed files in the
review archive match their candidate-tree blobs after adversarial probes were
restored. `git diff --check` is clean.

## Finding closure and architecture

Revision 3 closes revision-2 F1. `MacOSProductionBindingManifestValidator.bool`
now accepts only a real Core Foundation boolean, so JSON numeric `0` and `1`
cannot satisfy `productionCompositionPermitted` through Foundation bridging.
The production entry point is
`MacOSProductionDependencyFactory.makeRuntime()`: it loads and validates the
immutable accepted manifest before selected SSH construction or any public
component factory call. The attached and candidate manifests are byte-identical
at 17,492 bytes and SHA-256
`40333862b46b7af04cdd966ade91e8c9cc917e573c6601e26e7fa956d11ae161`.

The macOS root and deterministic harness both conform to the candidate-neutral
`TunnelRuntimeFactory`. The macOS root alone requires the accepted manifest and
owns the selected libssh2 transport, approved-host policy, system-domain
Keychain credential resolver, and credential diagnostic mapper. Core contains
no concrete libssh2, HEV C API, provider subclass, host-app object, or live
platform callback. `MacOSProviderCompositionRoot` continues to consume the root
through `any TunnelRuntimeFactory`; the concrete `NEPacketTunnelProvider` remains
outside this task's stated scope.

The coordinator composes one successful graph per generation. Startup performs
profile/SSH/TCP/DNS preparation and resource-free packet preflight, applies
network settings, then calls `activateReads`, which alone reaches
`PacketBridge.start`. Cleanup closes TCP/DNS admission, stops the packet/HEV
owner, clears settings, then releases DNS, TCP, and SSH; repeated stop is
idempotent. Private ingress routes ordinary TCP to TCP, virtual-DNS TCP/UDP to
DNS, and rejects all other UDP for M1.

## Adversarial evidence

- Boolean type-confusion mutant: replacing the exact-CFBoolean guard with
  `value as? Bool` made `semanticBooleanTypes` exit 1 because numeric JSON `1`
  returned accepted bindings. Restoring the candidate bytes made the same named
  test exit 0. Production call site:
  `MacOSProductionDependencyFactory.makeRuntime()`; invalid digest/permit inputs
  construct zero component factories.
- Activation-order mutant: moving the production coordinator's
  `activateReads` call before settings made the exact macOS test exit 1
  (`settings.apply` index 26 after `packet.descriptor` index 20) and the exact
  harness test exit 1 (apply index 9 after activate index 6). Restoring the
  candidate bytes made both tests exit 0.
- Boundary caller audit: `makeRuntime()` calls the manifest validator before
  component construction, and the Core boundary script requires the four
  selected SSH bindings while rejecting public security override surfaces.

## Verification

| Gate | Reviewer result |
| --- | --- |
| Manifest attachment vs candidate | exit 0; byte-identical, 17,492 bytes, exact accepted SHA-256 |
| Candidate blob restoration and `git diff --check` | exit 0; 11/11 changed blobs exact |
| `swift test --filter M1RuntimeCompositionTests` | exit 0; 10/10 |
| Exact macOS ownership | exit 0; 1/1 before probes and 1/1 after restoration |
| Exact deterministic harness | exit 0; 3/3 before probes and 1/1 after restoration |
| Boolean gate mutant / restored | expected exit 1 / exit 0 |
| Pre-settings activation mutant, macOS / harness | expected exit 1 / exit 1; restored exit 0 / exit 0 |
| Full `swift test` | exit 0; 508 tests / 43 suites; 25 known unavailable-ReluxNIOSSH issues |
| macOS adapter and harness builds | exit 0 / exit 0 |
| Unsigned macOS host/provider Debug+Release matrix and contract tests | first exit 2 on path-scoped untrusted `mise.toml`; after trusting only the exact candidate config, full rerun exit 0 |
| Core boundary guard | exit 0 |
| Native HEV/libssh2 pins and linkage | exit 0 |
| Accepted M0 live validation | exit 0; permitted, no failures, exact digest |
| M0 adversarial suite | exit 0; 32/32 |
| Strict recursive Swift format | exit 0 |

The full suite's 25 known issues are explicit evidence that the unselected
ReluxNIOSSH production adapter is absent; selected libssh2 coverage passed. The
real relux-host check and extended physical-Mac evidence tests remained
opt-in/NOT_RUN as designed and were not inferred as passes.

No signing, installation, app/provider launch, VPN start, live Keychain lookup,
external SSH connection, route mutation, or DNS mutation was performed. Local
Swift tests exercised task-scoped loopback and HEV fixtures and returned owned
resources to baseline.

## Board lifecycle note

The first `accept_cr` attempt named the legacy
`TASK-260715-3ejhyy_review-verdict.md` resource and was correctly refused with
`change_request_evidence_missing`: that name predated this reviewer run, so its
run manifest could not prove authorship despite a content update. This revision-
specific artifact is newly attached by the current reviewer run and is the
acceptance evidence.
