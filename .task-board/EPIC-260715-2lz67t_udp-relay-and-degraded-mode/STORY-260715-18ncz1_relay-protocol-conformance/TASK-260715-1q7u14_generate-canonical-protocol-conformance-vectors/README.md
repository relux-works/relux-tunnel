# Generate canonical protocol v1 conformance vectors

## Description
Create a production-code-independent canonical vector corpus containing encoded bytes, decoded values or expected errors, stream chunk plans, and limit metadata for every v1 message and address family.

## Scope
In scope: hello successes and failures; all envelope message types and legal directions; IPv4, IPv6, and domain datagrams; minimum and maximum frames; zero and maximum payloads; PING or PONG; errors and closes; fragmented and coalesced chunk plans; malformed lengths, flags, types, addresses, versions, and boundaries; stable corpus format and provenance. Out of scope: live sockets, remote hosts, fuzz-generated nondeterministic corpora, performance benchmarks, protocol v2, and real traffic samples.

## Acceptance Criteria
1. Each vector has a stable identifier, protocol version, input bytes, chunking where relevant, expected structured result or typed failure, and applicable negotiated limits. 2. The corpus covers every generated message and address value plus both sides of every numeric minimum or maximum and every specified failure-scope branch. 3. Vector bytes are produced or audited by a reference path independent from both production codecs so sharing one bug cannot make both consumers pass falsely. 4. The corpus is deterministic, contains only synthetic privacy-safe endpoints and payloads, and a documented review process makes incompatible edits visible. 5. Swift and relay harness loaders validate corpus schema and report the exact vector identifier without dumping payload bytes on failure.
