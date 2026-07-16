# Record the CI trust boundary and required quality-gate contract

## Description
Create the binding CI design that maps every trigger, actor, job, permission, secret boundary, environment, artifact, and required check for pull requests, protected branches, release candidates, and production publication.

## Scope
In scope: fork and same-repository pull requests, protected branches, tags, workflow dispatch, reusable workflows, GitHub token permissions, GitHub Environments, approval roles, Apple and GitHub credentials, action and runner trust, caches, artifacts, concurrency, retries, cancellations, gate ownership, and failure semantics. Out of scope: editing workflow files, issuing credentials, changing product tests, and selecting legal or App Review content.

## Acceptance Criteria
1. A TASK-ID-scoped contract enumerates every workflow trigger and job with actor trust, input source, token permissions, environment access, secrets, network access, outputs, and approval requirements. 2. Pull-request jobs default to read-only contents and no production environment, certificate, private key, issuer credential, provisioning profile secret, or publication permission. 3. A traceability matrix maps every epic CI requirement to one blocking check and identifies the downstream macOS, iOS, relay, or review owner. 4. Threat scenarios cover forked code, mutable actions, cache poisoning, artifact substitution, tag spoofing, reruns, cancellations, concurrent releases, and compromised low-privilege credentials. 5. Security and release owners approve the contract or disputed trust decisions remain explicit blockers with options and accountable owners.
