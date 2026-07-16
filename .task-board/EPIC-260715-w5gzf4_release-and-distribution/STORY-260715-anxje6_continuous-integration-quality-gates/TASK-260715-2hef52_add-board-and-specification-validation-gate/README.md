# Add board and specification validation as a required pull-request gate

## Description
Create a deterministic credential-free job that validates task-board structure and project specification integrity before changes can merge.

## Scope
In scope: task-board validation, resource reference integrity, hierarchy and dependency consistency, required identifiers, specification link and formatting checks available in the repository, planning artifact references, changed-file diagnostics, clean-checkout behavior, and required-check reporting. Out of scope: editing board or specification content automatically, reviewing product correctness, signing, and release publication.

## Acceptance Criteria
1. One documented command runs from a clean checkout and validates the board, its resources, dependency graph, and all supported specification checks without network credentials. 2. Missing resources, broken task IDs, invalid hierarchy or status data, dependency cycles, malformed specification references, and controlled formatting failures cause a nonzero result with actionable file and rule output. 3. The job cannot mutate tracked board or specification files and a post-run cleanliness check proves no generated drift. 4. The gate runs for pull requests and protected branches with read-only permissions and bounded artifact output. 5. Tests or fixtures demonstrate both a passing repository and each supported failure class.
