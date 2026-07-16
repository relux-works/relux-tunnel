# Implement the tunnel-owned UDP and TCP DNS listener

## Description
Implement the bounded DNS ingress component reachable only through the virtual network. Accept client UDP and TCP DNS queries for IPv4 and IPv6, parse enough protocol structure to enforce limits and correlation safely, and forward normalized query transactions to the tunneled upstream interface.

## Scope
In scope: virtual listener addresses from the network contract, UDP datagrams, TCP two-byte length framing, incremental and coalesced TCP reads, transaction correlation, EDNS size bounds, maximum query and connection counts, deadlines, duplicate IDs across clients, cancellation, response delivery, malformed input handling, aggregate metrics, and provider cleanup. Out of scope: physical-interface listeners, upstream selection, direct-tcpip channel implementation, recursive resolution, query rewriting, fake DNS, destination logging, general UDP forwarding, and caching policy owned separately.

## Acceptance Criteria
1. Only packets addressed to the configured tunnel DNS service are accepted, for both IPv4 and IPv6 client paths, and no physical socket is bound for ordinary resolver fallback. 2. Valid UDP and TCP queries, including split and coalesced TCP frames, map to isolated bounded transactions and return responses to the correct client and transport. 3. Invalid headers, zero or oversized TCP lengths, truncated messages, excessive EDNS sizes, unsupported opcodes where policy rejects them, floods, timeout, and cancellation consume bounded memory and return or drop per the contract. 4. Concurrent clients with repeated transaction IDs cannot cross-deliver responses. 5. Unit and provider-harness tests verify limits, fairness budgets, cancellation, socket or transaction cleanup, and metrics without recording query names.
