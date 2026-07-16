# Add cross-language protocol conformance, hostile-input, and fuzz tests

## Description
Build the common quality gate that runs canonical vectors and adversarial stream cases through both protocol implementations and proves bounded time, memory, state, and diagnostics under arbitrary input.

## Scope
In scope: both corpus consumers; every incremental cut; multiple-frame permutations; mutated magic, version, status, lengths, flags, type, associationID, inner payload, address, and close sequences; deterministic fuzz seeds; coverage corpus; allocation and iteration ceilings; cancellation; sanitizer or runtime diagnostics supported by each toolchain; CI commands. Out of scope: network fuzzing against public hosts, relay socket behavior, asset installation, physical-device performance, retaining real packets, and weakening expected failures per implementation.

## Acceptance Criteria
1. Every canonical vector passes in both implementations and failures compare by stable semantic code rather than implementation-specific text. 2. Exhaustive small-frame splits and representative coalesced sequences preserve ordering and result without hang, busy loop, cross-frame state, or bytes retained after reset. 3. Fuzzing and hostile declared lengths cannot crash, trap, recurse without bound, allocate above configured ceilings, leak tasks, or cause divergent session-versus-association disposition. 4. A checked deterministic corpus reproduces every discovered failure and CI records duration, cases, peak allocation, retained buffers, and seed without payload content. 5. The gate fails when generated constants, vector schema, Swift behavior, or relay behavior drift and publishes commands usable in local and target CI environments.
