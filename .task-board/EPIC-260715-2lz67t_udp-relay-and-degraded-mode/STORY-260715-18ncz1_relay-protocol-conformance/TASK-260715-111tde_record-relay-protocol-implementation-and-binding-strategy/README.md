# Record the relay protocol implementation and binding strategy

## Description
Convert the approved generated-project and relay-toolchain decisions into the binding plan for protocol source ownership, code generation, language boundaries, streaming abstractions, and test reuse before any wire implementation begins.

## Scope
In scope: consume TASK-260715-32umrc; language-neutral schema format; Swift and selected relay-language bindings; generated versus handwritten ownership; regeneration command; module placement; endian and bounded-buffer primitives; dependency and license ceiling; test-vector consumption; versioning and review rules. Out of scope: reselecting the approved relay language or project generator, implementing codecs, building binaries, UDP sockets, remote bootstrap, and protocol v2 design.

## Acceptance Criteria
1. A TASK-ID-scoped decision record references the approved project and relay-toolchain ADR and names the exact schema, generated outputs, handwritten adapters, modules, and owners. 2. It defines one deterministic regeneration command, reviewable generated diffs, and a CI drift check that fails hand-edited or stale outputs. 3. The chosen byte and stream abstractions operate within the Apple extension and rootless Linux or macOS constraints without blocking I/O or unbounded allocation. 4. Runtime dependencies, licenses, unsafe or FFI use, error surfaces, and source-versus-build trust boundaries are enumerated and remain within the approved ceiling. 5. Every downstream protocol, build, bootstrap, and UDP task maps to a concrete artifact or interface in the decision and has no unresolved language choice.
