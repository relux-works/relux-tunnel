# TASK-260720-1qhxqa review verdict — CR revision 4

Verdict: CHANGES REQUESTED. Route to `to-dev`.

## Blocking finding

`EXPECTED_NORMALIZED_CONTRACT_SHA256` does not bind any accepted outcome or
reviewer-verdict SHA-256. `canonical_contract_payload()` deliberately omits all
eight digest fields, while `verify_resource()` trusts the digest supplied by
the mutable manifest. A caller can therefore replace an accepted upstream
resource, update the corresponding manifest `sha256`, and retain permission
without a new reviewer-accepted binding revision.

The production CLI mutant changed
`TASK-260715-2jatnd_m0-bridge-hev-decision-adr.md`, recomputed its manifest
digest, and exited 0 with `failures=[]` and
`productionCompositionPermitted=true`. This violates AC1 and AC4: the manifest
does not immutably bind the exact accepted content digest, and changed upstream
bytes can silently retain permission. It is a narrowing proof, not a delete-only
mutant.

Required rework:

- Include all accepted outcome and reviewer-verdict SHA-256 values, including
  the M1 runtime-contract pair, in the independently pinned immutable contract
  payload (or enforce an equivalent independent digest allowlist).
- Add a production-entry negative test that changes an upstream resource and
  updates the manifest digest to match; it must exit 1 with
  `productionCompositionPermitted=false` at a stable row.
- Re-run the exact accepted-resource digest check, baseline Make gate, full
  binding suite, lint, candidate/patch identity, and board validation.

## Independent evidence

- Exact CR candidate: all seven worktree files byte-match candidate tree
  `8726b6394d5e10ea722e2f82a32854a6de27cb06`; exact binary diff SHA-256 is
  `58d2b77da2f7c997c2cc0fe226283676b0c0a99e6f087abfa856005bc28743b7`.
- All eight authoritative upstream resource SHA-256 values independently match
  the manifest. Owner, repository, and `TASK-260715-3ejhyy` consumer copies of
  the manifest are byte-identical at
  `39b3428d6cf778fa6b682bb0853a177d6b85f03b8062309f0d198dcdfd49fae6`.
- Baseline `make m0-bindings-check`: exit 0, permission true.
- `python3 -m unittest -v scripts.tests.test_m0_production_bindings`: exit 0,
  16 tests passed.
- Python compile plus exact candidate `git diff --check`: exit 0.
- Digest-rebind production mutant: exit 0 and permission true — blocking red
  evidence.
- `task-board validate`: process exit 0 but reported three
  `PARENT_STATUS_MISMATCH` rows, including owning Story stored `to-dev` versus
  child aggregate `reviewing`; this is preserved as an anomaly and is not
  described as clean validation.

The reviewer made no repository changes, supplied no `commit_ack`, and did not
accept CR revision 4.
