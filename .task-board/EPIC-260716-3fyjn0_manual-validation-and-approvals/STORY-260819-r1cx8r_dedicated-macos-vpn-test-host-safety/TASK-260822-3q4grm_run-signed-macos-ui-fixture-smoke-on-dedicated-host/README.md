# TASK-260822-3q4grm: run-signed-macos-ui-fixture-smoke-on-dedicated-host

## Description
Run the isolated non-networked ReluxProxyMacUITests fixture-host smoke on the dedicated macOS test host with test-only signing. Preserve the no-provider boundary: do not build install configure enable or start the packet-tunnel provider or mutate routes DNS interfaces or VPN preferences.

## Scope
Signed execution of only the fixture host and XCUITest runner on the dedicated Mac; produce xcresult step screenshots extracted images and visual-review evidence. Out of scope: packet-tunnel provider launch system VPN configuration network mutation notarization and product signing.

## Acceptance Criteria
1. A harmless preflight proves the destination is the dedicated test Mac and not the current build host. 2. The isolated fixture host and UI-test runner are test-signed without building or launching the provider. 3. Native macOS smoke passes and produces xcresult plus step-named extracted screenshots. 4. Screenshots pass documented orientation layout content and black-screen visual inspection. 5. Task-scoped evidence contains no secrets device identifiers or signing material.
