# Harden GitHub Actions permissions, dependencies, and runner inputs

## Description
Apply the approved CI trust contract to workflow-level and job-level permissions, third-party action revisions, environment access, runner selection, shell behavior, caches, and artifact transfer.

## Scope
In scope: explicit permissions blocks, read-only defaults, job elevation only when required, full commit-SHA action pins, Dependabot or equivalent update ownership, trusted runner labels, safe shell flags, environment protection, cache keys and restore scope, artifact names and digests, log masking, timeouts, and concurrency. Out of scope: release job business logic, Apple credential creation, product code, and accepting mutable tags for convenience.

## Acceptance Criteria
1. Every workflow and reusable workflow has explicit minimum permissions and no job inherits write access it does not use. 2. Every external action is pinned to a reviewed immutable commit with owner, update path, and provenance; mutable tags fail validation. 3. Fork pull requests cannot select protected environments, runners with production material, privileged reusable workflows, write-capable tokens, or unsafe cache and artifact namespaces. 4. Shells fail on errors and unset values, jobs have bounded timeouts, logs mask sensitive values, and cancellations release concurrency without publishing partial output. 5. Automated policy tests inspect all workflows and fail controlled fixtures for excessive permissions, mutable actions, untrusted runner labels, unsafe cache reuse, missing timeouts, or environment exposure.
