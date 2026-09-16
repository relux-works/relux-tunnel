# TASK-260715-2zmw58 — review verdict for CR revision 1

## Verdict

Accepted. Change Request `CR-TASK-260715-2zmw58-1` revision 1 matches the
task acceptance criteria and the accepted M1 resolver decision without
creating another resolver policy.

## Scope reviewed

- Base OID: `b3422b05226253a17676b9b84c764071fe3dbe74`.
- Candidate tree OID: `72e1cc2b7a4bf656dc577b1b5e50c8abb221b85e`.
- Repository delta: six added `LOGBOOK.md` lines only.
- CR patch SHA-256: `d0685c4e755acd00625578c9f9d805390ea31df361917c9bc4da2ebcaded0781`;
  the attached patch is byte-identical to the exact base-to-candidate diff.
- The degraded contract, producer handoff, accepted M1 decision/review, binding
  M2 capability input, linked dependencies, and concrete downstream owners
  were inspected independently.

## Acceptance evidence

1. The decision reuses accepted ADR-022 identity unchanged: required ordered
   canonical numeric `dns53` endpoints, port default 53, stored cross-family
   order, and authenticated SSH `direct-tcpip` DNS-over-TCP. DoH remains
   deferred because the accepted policy supplies no DoH identity or trust
   inputs.
2. Every required numeric policy field is named, while exact numeric defaults
   remain truthfully unavailable until existing owner `TASK-260721-3miqh4`
   produces independently accepted `DNSRuntimePolicyV1` authority. Production
   therefore fails before routes with `production_policy_unauthorized`; no
   candidate values are laundered into defaults.
3. Prepared DNS is not public readiness. The contract binds public degraded
   `(1,1,0)` to current `BaseReady(g)` after settings, packet reads, and
   mandatory health recheck. Exhaustion or current mandatory loss closes
   admission, publishes all bits false, clears settings, and cannot select a
   physical/system/vendor/discovered resolver or start relay-only reprobe.
4. Client UDP/TCP ingress, TCP pooling and coordinated promotion, TC/oversize,
   cache generations, DNSSEC transparency, cancellation, profile change,
   relay restoration, privacy-safe diagnostics/UI, and zero query-name logging
   are specified.
5. The downstream impact map names existing concrete integration, capability,
   state, leak, documentation, profile, and UI task IDs. Queried board state
   confirms the IDs and dependency chain exist. Six direct consumers carry
   byte-identical copies of the contract at SHA-256
   `1a62feab78080f2e1641536af1de7dfb2e07fb9ee019e73355dadd8918293661`.

## Gate and negative-evidence review

This revision changes no executable gate, validator, authorization path, or
attestation, so no new production negative test ships in this CR. The decision
does require downstream negative proofs through the real production call
sites, including `TunnelRuntimeCoordinator.runStartup()`,
`DNSConsumerFactory.prepareSafeDNS(...)`, and
`TunnelRuntimeCoordinator.receive(_:)`. Repository inspection confirms those
call sites exist and that current startup calls safe-DNS preparation before
settings, activates packet reads, rechecks mandatory health, and routes current
unhealthy events through `receive(_:)`. The contract explicitly requires
narrowed-gate/bypass mutants rather than delete-only or helper-only evidence.

## Independent verification

- `git diff --check <base> <candidate>`: exit 0.
- Candidate-versus-working-tree diff: empty.
- Exact CR patch comparison: exit 0.
- Assignment M2 input: 64,673 bytes and expected SHA-256
  `5b57540c86a0b48595863174e416229babee72cdb2705dd4bbb81bbefdc9ab69`.
- Accepted M1 decision/review SHA-256 values match the contract exactly.
- `make check-core-boundaries check-native-dependencies`: exit 0.
- `make core-test`: exit 0; 494 tests in 40 suites passed with 25 known
  unavailable-ReluxNIOSSH-adapter issues.
- `make core-build`: exit 0.
- `task-board validate`: process exit 0 but reported two semantic
  `PARENT_STATUS_MISMATCH` issues. One is the current hard-blocked Story whose
  parent cannot aggregate to the reviewing child; the other is out-of-scope
  `STORY-260715-1y04r0`. Neither is presented as a passing board gate or caused
  by the six-line candidate delta.

No DNS query, socket, VPN, route, credential, signing, installation, provider
launch, or remote execution was performed during review.
