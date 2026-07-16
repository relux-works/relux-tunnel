# Pin and audit the HEV and lwIP baseline

## Description
Establish the exact upstream HEV dependency set used by the M0 bridge spike and verify its Apple build, descriptor contract, UDP-in-TCP framing, configuration keys, licenses, notices, and fork baseline from primary source.

## Scope
In scope: hev-socks5-tunnel, hev-socks5-core, hev-task-system, bundled lwIP, exact commits and submodules, source hashes, Apple build instructions, descriptor ownership, Darwin family header behavior, socks5.udp tcp mode, low-memory settings, licenses, notices, and upstream issue or patch inventory. Out of scope: modifying upstream, implementing the bridge, selecting production performance constants, or accepting an unpinned release tag.

## Acceptance Criteria
1. A TASK-ID-scoped dependency manifest records exact commits, submodule or vendored relationships, hashes, build flags, target architectures, upstream URLs, and inspected file paths. 2. Primary-source evidence confirms the packet descriptor contract, four-byte Darwin family header expectations, UDP-in-TCP framing, and every configured low-memory key. 3. MIT and bundled lwIP notice obligations are enumerated and sample binary-distribution notices are generated from the pinned sources. 4. Apple provider and harness build risks, global state, threading model, allocator hooks, shutdown contract, and known patches are documented. 5. The baseline declares unmodified upstream as default and defines the evidence required before any fork.
