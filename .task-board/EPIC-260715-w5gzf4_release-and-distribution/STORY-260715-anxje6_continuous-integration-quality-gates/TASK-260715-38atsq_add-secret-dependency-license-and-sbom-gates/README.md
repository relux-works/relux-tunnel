# Add secret, dependency, license, vulnerability, and SBOM gates

## Description
Create credential-free security and compliance jobs that scan source, history or diffs as approved, generated artifacts, dependency locks, binaries, manifests, SBOMs, and third-party notices against an explicit exception policy.

## Scope
In scope: secret detection, dependency review, known-vulnerability scanning, license allow and deny policy, SBOM schema and completeness checks, third-party-notice coverage, artifact scanning, suppression format, expiry and owner, false-positive fixtures, redaction, and machine-readable results. Out of scope: silently accepting vulnerabilities, storing scanner tokens in pull requests, legal conclusions by automation, remediating dependencies, and replacing the relay compliance story.

## Acceptance Criteria
1. Pull requests run without production credentials and fail on controlled private-key, token, password, prohibited-license, vulnerable-dependency, missing-SBOM-component, and missing-notice fixtures. 2. Scanner versions, databases or advisory timestamps, dependency locks, inputs, results, and policy revision are recorded reproducibly. 3. Exceptions require scoped identifiers, rationale, owner, approval, expiration, and affected artifacts and cannot suppress unrelated findings. 4. Reports and logs redact discovered secrets and do not upload sensitive fixture contents or repository credentials. 5. Release candidates rerun the same policies against exact binaries and compliance artifacts and any unresolved blocking finding prevents promotion.
