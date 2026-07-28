# Record the CI trust boundary and required quality-gate contract

## Description
Record the binding CI trust and quality-gate contract for the macOS-first prototype and the later release path. The contract is authored from the accepted macOS project architecture and the approved macOS-only physical target; Gate A0 evidence is not an input because A0 is deferred outside the prototype critical path, and no Linux CI runner is required for the working-client path.

## Scope
In scope: required workflows, triggers, permissions, secrets posture, artifact retention, provenance, required-check policy, credential-free build validation, board and specification validation, and the failure semantics that must fail closed. Out of scope: reinterpreting Gate A0 (deferred), requiring a Linux runner for the macOS prototype path, iOS TestFlight and App Store workflows (deferred with iOS), and implementing the workflows themselves.

## Acceptance Criteria
1. A TASK-ID-scoped contract enumerates every workflow trigger and job with actor trust, input source, token permissions, environment access, secrets, network access, outputs, and approval requirements. 2. Pull-request jobs default to read-only contents and no production environment, certificate, private key, issuer credential, provisioning profile secret, or publication permission. 3. A traceability matrix maps every epic CI requirement to one blocking check and identifies the downstream macOS, iOS, relay, or review owner. 4. Threat scenarios cover forked code, mutable actions, cache poisoning, artifact substitution, tag spoofing, reruns, cancellations, concurrent releases, and compromised low-privilege credentials. 5. Security and release owners approve the contract or disputed trust decisions remain explicit blockers with options and accountable owners.
