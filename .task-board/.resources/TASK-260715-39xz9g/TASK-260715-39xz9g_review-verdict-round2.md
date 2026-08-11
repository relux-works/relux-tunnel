# TASK-260715-39xz9g — reviewer verdict, round 2

Verdict: changes requested; route to `to-dev`.

## Acceptance findings

1. **The delivered artifacts still do not provision or resolve the server fixtures (AC1–AC3).** The checked-in `orchestrate` command delegates every server action to five environment-provided commands, but no provider implementation or successful real orchestration report is delivered. In the review environment all five references were missing. Running `python3 scripts/ssh_matrix_fixture.py orchestrate --output .temp/TASK-260715-39xz9g/reviewer-probe.json` exited 1 before provisioning and reported `1 provider teardown action(s) failed`. `make ssh-fixtures-test` only validates the manifest/preflight declarations and a mock invoker; it does not make current Linux, current macOS, the compatibility profile, or the real relux row reproducibly reachable.

2. **Required negative/rekey branches can pass without being produced (AC3 and DoD matrix coverage).** The test driver in `scripts/tests/test_ssh_matrix_fixture.py:281` always returns `status: pass`. Its exercise helper at line 292 performs socket work only for latency, loss, success, early-close, half-close, reset, and disconnect. Host-key first use, host-key change, authentication rejection, channel rejection, and server rekey execute no fixture action before the pass is accepted. The provider protocol exposes only prepare/rotate/probe/teardown and one unchanged runtime, so it has no defined scenario control for a changed host key, an unapproved user key, or a known closed remote destination. This is declaration coverage, not deterministic fixture coverage.

3. **Task-owned credential rotation is not enforced.** `scripts/ssh_matrix_fixture.py:807-810` accepts both `rotated` and `external-owner-managed` for every server. A review probe changed every row to `external-owner-managed`; the complete orchestration still succeeded and all lifecycle rows retained that disposition. This contradicts the task contract that only `relux-real` is externally owner-managed while task-owned macOS/Linux identities must rotate.

4. **The privacy-safe report boundary is open-ended (AC5).** `observationCode` is persisted after only checking the scenario prefix at lines 757-768. A review probe successfully persisted `success:private-host.example/user/alice`. The final marker scan only catches a few private-key/password spellings, so arbitrary hostnames, usernames, paths, addresses, or credential text can enter the board/report artifact. Observation codes need a finite public enum or an equivalently strict allowlist and privacy regression tests.

## Independent gates

- `make ssh-fixtures-test`: exit 0; 28 tests passed.
- `swift test`: exit 0; 428 tests in 35 suites passed.
- Python stdlib trace coverage: exit 0; 83.5% for `scripts/ssh_matrix_fixture.py`.
- Python compilation, strict Swift format lint, manifest JSON parse, and `git diff --check`: exit 0.
- Streamed 5 GiB source/sink: exit 0; 5,368,709,120 bytes and `SHA256:fc01cfd7aebf90ff9491f8556131b6ef575c3e1fa33a0277ba28920bbaee7f54`, with no payload file.
- Real orchestration reproducibility probe: exit 1; all five provider/driver environment references were absent.
- `task-board validate`: exit 0 while reporting the known `PARENT_STATUS_MISMATCH` for `STORY-260715-lkshfz`.

## Required rework

- Deliver privacy-safe executable providers for task-owned macOS/Linux rows and the approved real-host resolver, or an equally reproducible checked-in implementation that resolves external secret references without embedding secrets.
- Extend the fixture/provider protocol with deterministic controls for changed/first-use host keys, rejected user authentication, a guaranteed rejected direct-tcpip destination, and server rekey; add integration evidence that each branch is actually exercised instead of accepting a mock pass string.
- Enforce `rotated` for task-owned rows and `external-owner-managed` only for `relux-real`.
- Replace free-form observation codes with a finite privacy-safe contract and reject arbitrary host/user/path/address/credential text.
- Attach a privacy-safe successful provider lifecycle/teardown report proving the delivered reproduction path; destructive negative fixtures remain task-owned and must not mutate the real host.
