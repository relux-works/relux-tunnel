# Document the verified Apple platform exception and support matrix

## Description
Publish the evidence-backed M3 platform behavior record for supported iOS and macOS releases, covering NAT64, path changes, sleep and wake, captive negotiation, compatible and fail-closed routes, app termination, provider stops, limitations, regression triggers, diagnostics, and downstream disclosures.

## Scope
In scope: implemented state and traffic diagrams; device and OS support table; verified automatic endpoint exclusion behavior; includeAllNetworks availability; documented and observed captive and system exceptions; NAT64 and family behavior; lifecycle ownership; full and degraded behavior; red and unavailable rows; reproduction links; privacy-safe diagnostics; M4 UX and privacy handoff; release regression checklist. Out of scope: changing implementation, marketing promises, final legal approval, absolute kill-switch language, hiding red evidence, unsupported platform extrapolation, or raw sensitive captures in documentation.

## Acceptance Criteria
1. A TASK-ID-scoped document references every automated and Apple-silicon Mac evidence row, records iPhone rows as deferred-unavailable under ADR-024, and states supported, red, unavailable, or changed behavior by exact OS and hardware context. 2. Diagrams and traffic tables accurately show actual endpoint exclusion, safe DNS, reconnect, route modes, NAT64, sleep or wake, captive exceptions, app independence, stop, and failure without contradicting implementation. 3. Compatible and fail-closed wording explicitly bounds Apple system and captive exclusions and does not claim cryptographic absolute blocking. 4. Each red, unavailable, or changed API or OS row has reproduction steps, impact, owner, required decision or fix, and regression trigger rather than a waiver. 5. Diagnostics, support, UX, privacy, and release handoffs list only redacted categories and concrete downstream task IDs and raw artifact references.
