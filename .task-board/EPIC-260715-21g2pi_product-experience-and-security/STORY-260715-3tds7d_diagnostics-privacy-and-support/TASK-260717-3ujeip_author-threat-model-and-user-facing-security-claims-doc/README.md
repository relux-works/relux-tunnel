# TASK-260717-3ujeip: author-threat-model-and-user-facing-security-claims-doc

## Description
Author a dedicated threat-model and user-facing security-claims document (.spec/threat-model.md plus the shippable claims copy it feeds). Define assets, adversaries (on-path/local-network observer, exit-host operator, malicious/compromised remote host, App Store/CI supply chain, lost/stolen device), trust boundaries (UI process vs NE extension vs remote sshd/relay), and an explicit does-hide / does-NOT-hide matrix. State plainly: SSH metadata is visible to the on-path observer, the exit host sees destination metadata and plaintext, Relux Works is not in the baseline path, long-lived SSH sessions are fingerprintable (no DPI-evasion claim), fail-closed is platform-scoped not absolute. AC: doc exists and is internally consistent with security-privacy.md and architecture.md; every claim is provable from the design; it enumerates residual risks and non-goals; it is the single source the disclosure UI, privacy copy, and privacy policy derive from. Autonomous: derived from existing specs; agent-reviewer acceptance = done.

## Scope
(define task scope)

## Acceptance Criteria
(define acceptance criteria)
