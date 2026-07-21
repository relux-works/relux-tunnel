# TASK-260715-27uz4n — Review 03 focus

Fresh independent review after rework-02. Reproduce the review-02 symlink escape first, then audit the complete task.

Isolation acceptance:

- A symlinked sandbox root must fail with the exact root diagnostic in both clean and incremental modes and through direct sanitized_environment use.
- A non-directory root must fail without deletion or traversal.
- Each HOME, TMPDIR, GOCACHE, GOMODCACHE, and GOPATH child must reject symlink and unsafe types with an exact variable-specific diagnostic.
- Each resolved child must be proven beneath the resolved sandbox root; direct helper use with an outside path must fail closed.
- Legitimate incremental reuse must preserve its target-local marker; clean mode must remove it and recreate a safe directory.
- Inspect for TOCTOU or parent-component escapes; do not accept solely from unit tests.

Regression acceptance:

- Re-run the five original review findings: full official-Go-tree tamper/type/mode/path checks, exact HEAD-based missing inputs, honest Linux Ubuntu 24.04 native fixture boundary, exact actions/checkout v7.0.1 pin equality, and exact GOAMD64/GOARM64 metadata.
- Re-run 26 Python tests, four-target offline build, two-build byte reproducibility, linkage/runtime metadata, SBOM/licenses/notices, macOS arm64 and Rosetta smoke, plus Black, py_compile, shell syntax/ShellCheck, Actionlint/YAML, privacy, diff, and board validation.
- Inspect manifest/docs/LOGBOOK against implementation and every AC.

Issue exactly one board verdict with a new task-scoped outcome. Accept only if the isolation fix is structurally sound and all prior evidence remains green.
