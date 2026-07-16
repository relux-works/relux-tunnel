# Document compatible routing, leak-free DNS, and Apple exceptions

## Description
Document the implemented M1 address plan, compatible routes, SSH bootstrap and exclusion, DNS ingress and SSH-only upstream, cache and TC behavior, startup and failure order, diagnostics, physical evidence, troubleshooting, and accurately bounded Apple system exclusions. Link later fail-closed, path, relay, UX, and release work.

## Scope
In scope: component and sequence diagrams, setting field tables for both platforms, resolver policy and profile impact, DNS flow, cache and failure table, route-loop prevention, external-IP and capture procedures, privacy-safe diagnostics, known compatible-mode and Apple exclusions, test commands, and M2 through M5 handoffs. Out of scope: claiming an absolute kill switch, final privacy policy or onboarding copy, reconnect procedure, general UDP, final UI, release review notes, and implementation changes.

## Acceptance Criteria
1. Diagrams show SSH bootstrap on the physical path before routes, exact endpoint exclusion, tunnel-owned DNS ingress, SSH DNS-over-TCP, and application TCP through HEV and direct-tcpip. 2. Tables list virtual addresses, prefixes, included and excluded routes, MTU, DNS addresses, match domains, resolver policy, cache bounds, timeouts, and every failure outcome. 3. Documentation states that ordinary DNS never falls back while accurately disclosing Apple system traffic and compatible-mode exceptions without an absolute kill-switch claim. 4. Reproduction instructions cover unit, fault, harness, iPhone, and Mac matrices plus authorized leak-capture interpretation and redaction. 5. Links identify M2 UDP or degraded capability, M3 reconnect or fail-closed work, M4 product disclosure, and M5 App Review validation by concrete board scope.
