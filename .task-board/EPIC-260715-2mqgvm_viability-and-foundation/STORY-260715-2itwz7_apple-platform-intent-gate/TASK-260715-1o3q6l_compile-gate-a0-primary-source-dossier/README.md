# Compile the Gate A0 primary-source evidence dossier

## Description
Produce a dated, source-pinned dossier that maps the exact Relux packet-tunnel architecture to current Apple intended-use, routing, entitlement, and VPN review guidance. Separate documented facts from architectural inference so the later Apple inquiry starts from an auditable record.

## Scope
In scope: NEPacketTunnelProvider, NETunnelProviderManager, TN3120, Apple VPN routing guidance, App Review Guideline 5.4, the supplied Relux data paths, accepted Gate A0 evidence forms, access dates, and point-in-time caveats. Out of scope: contacting Apple, interpreting a future response, legal advice, changing the architecture, or writing product code.

## Acceptance Criteria
1. A TASK-ID-scoped outcome resource lists every primary Apple source with direct URL, access date, relevant requirement in paraphrase, and the architecture behavior it governs. 2. A traceability table covers local HEV TCP termination, SSH direct-tcpip, UDP relay over SSH exec, DNS handling, default routes, endpoint exclusions, and containing-app versus provider ownership. 3. Facts, inferences, unresolved ambiguity, and assumptions are visibly separated. 4. The dossier states why successful local installation is not Gate A0 evidence and enumerates the accepted authoritative evidence routes. 5. Another researcher can reproduce the source review from the recorded references and revision.
