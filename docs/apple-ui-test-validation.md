# Apple UI-test and screenshot validation

This is the reusable UI-validation foundation for the macOS client and the
shared iOS Simulator proof. It is deliberately isolated from production tunnel
behavior: the two fixture hosts have no dependency on NetworkExtension, either
platform adapter, the packet-tunnel provider, VPN preferences, credentials, or
network clients.

## Source and target ownership

`ReluxAppleUITestShared` is the single source of truth for accessibility
identifiers, timeout values, typed launch keys, and deterministic fixture names.
The macOS containing app imports the module as a compile-time integration anchor;
both fixture hosts and both UI-test targets consume the same package product.
Raw `RELUX_UI_TEST_*` keys are confined to
`ReluxUITestLaunchConfiguration.swift` and checked by
`scripts/check-apple-ui-test-contract.py`.

The generated test-only target graph is:

```text
ReluxProxyMacUITests -> ReluxProxyMacUITestFixtureHost -> ReluxAppleUITestShared
ReluxProxyIOSUITests -> ReluxProxyIOSUITestFixtureHost -> ReluxAppleUITestShared
```

The dormant production `ReluxProxyIOS` and `ReluxProxyIOSTunnel` targets remain
deferred. The iOS target above is a simulator-safe fixture host, not resumed
product scope. Neither UI-test scheme embeds or builds a packet-tunnel provider.

`ReluxUITest.PageElement`, `ComponentElement`, `PageManager`, and
`Page.FixtureHost` are shared by the two UI-test targets. Page methods describe
the expected state or action (`waitForAppearance`, `waitForFixture`,
`confirmFixture`) and synchronize with `waitForExistence` or XCTest predicate
expectations. Fixed wall-clock sleeps are prohibited by the contract check.

## Deterministic fixture launch

Construct only `ReluxUITest.LaunchConfiguration(fixture:)`. It generates the
complete launch arguments and environment; tests and scripts must not spell raw
keys independently. Parsing fails closed unless the current schema, a known
fixture, UI-test mode, and the `disabled` network boundary are all present.

The fixture matrix covers:

- profile: empty, configured;
- trust: unknown, approved, changed, revoked;
- capability: available, unavailable;
- failure: authentication, transport, relay;
- diagnostic: empty, populated;
- onboarding: required, complete;
- migration: required, complete;
- privacy: redacted.

Every value is a deterministic non-secret enum case. The fixture host renders
only public labels and cannot connect, mutate VPN preferences, request system
extension or NetworkExtension approval, or bypass a production safety decision.

## Smoke, xcresult, extraction, and diffs

Run the focused contract gate first:

```bash
make apple-ui-test-contract
```

Run the complete build-host gate and a controlled snapshot mismatch with:

```bash
make apple-ui-test-smoke
```

Each invocation creates a unique directory below
`.temp/TASK-260715-1idq8c/apple-ui-test/`. The native macOS row performs an
unsigned `build-for-testing`, retains its Xcode log and `.xctestrun` product
inventory, and does not launch the app or test runner. The iOS Simulator row
runs the smoke, writes an `.xcresult` and Xcode log, then passes the result to
`scripts/extract_apple_ui_test_artifacts.py`. The extractor exports only
`Step_*` PNG attachments into test-specific directories and writes
`screenshots.json`. The runtime row then independently validates that manifest,
requires non-empty PNG files for both expected smoke steps, and propagates any
extractor or validation failure to the aggregate gate. The focused contract
gate includes an injected extractor-failure regression against the production
smoke script.

The controlled mismatch invokes `relux-snapshot-diff`. An image mismatch is the
expected exit code `1` and must produce the three review files
`reference.png`, `failed.png`, and `diff.png`. Exit `0` means the images match;
exit `2` means the comparison could not be performed. Product-screen SwiftUI
snapshot suites are intentionally not added before product screens exist; the
diff engine and Swift Testing artifact suite establish the failure workflow
without inventing business UI.

This workstation keeps `CODE_SIGNING_ALLOWED=NO` and
`CODE_SIGNING_REQUIRED=NO`. The iOS Simulator row can run unsigned. Native
macOS runtime proof is explicitly deferred to `TASK-260822-3q4grm` on the
dedicated signed test host. `summary.txt` records that owner and distinguishes
the successful native macOS build-for-testing row from the deferred runtime
row. Do not sign, install, or launch the native fixture here to make that row
look complete.

## Mandatory visual review

Extraction is not acceptance. A human or reviewing agent must open every
step-named PNG and record a result for all four checks:

| Check | Required evidence |
| --- | --- |
| Orientation | expected portrait/landscape orientation; no rotation or sideways content |
| Layout | content uses the expected viewport; no clipped, collapsed, or corner-squashed UI |
| Content | required state labels/actions are present and readable |
| Rendering | image is not empty, black, frozen on launch, or otherwise missing the app UI |

Record the inspected filenames, destination, and pass/fail findings in the
task-scoped outcome. A passing test process without this review is incomplete.

## Separate physical-device evidence contract

Physical-device-only evidence is never inferred from Simulator, native Mac, or
unsigned build results. Each later physical row must attach a separate resource
named `TASK-<row-id>_physical-apple-ui-evidence.md` and a task-scoped artifact
directory containing:

- device class/model and OS/build (identifier redacted to a non-reversible
  suffix or lane-local alias);
- exact authorized test command, destination class, scheme, test identifier,
  and exit code;
- `.xcresult`, extracted step screenshots, and `screenshots.json`;
- the four-field visual review above for every screenshot;
- signing/provisioning lane name without certificate, profile, Keychain, UDID,
  credential, or secret bytes;
- explicit statement whether the row is fixture-only or separately authorized
  for product/system VPN behavior.

Any row that installs or launches the product/provider, requests approval,
creates or changes VPN preferences, or exercises real routing/DNS/tunnel state
belongs to its named physical security gate and must not be run under this
fixture smoke contract. Designed-for-iPad Mac is not a UI-test destination.
