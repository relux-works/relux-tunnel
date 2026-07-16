# Establish shared Apple UI-test and screenshot infrastructure

## Description
Create the reusable iOS and macOS UI-validation foundation for all M4 stories, following shared accessibility identifiers and Page Objects. Provide deterministic test launch configuration, screenshot extraction, visual review, and snapshot-diff workflows without coupling production behavior to tests.

## Scope
In scope: a shared test constants target, BEM-like identifiers, typed launch arguments/environment, PageElement and ComponentElement protocols, PageManager composition, deterministic profile/trust/session/diagnostic fixtures, XCUITest result bundles, step screenshots, extraction into task-scoped temporary output, Swift Testing snapshot suites where appropriate, failed-snapshot diff artifacts, iOS Simulator and native macOS destinations, and documentation of physical-device-only rows. Out of scope: product screens, production credentials, wall-clock sleeps, Allure unless already selected by the project, running iOS UI tests on Designed-for-iPad Mac, and business-specific test assertions.

## Acceptance Criteria
1. Shared identifiers and typed test arguments compile in both containing apps and both UI-test targets with one source of truth and no raw string duplication. 2. Page Objects expose descriptive waits/actions and use condition-based synchronization rather than fixed sleeps. 3. Deterministic fixtures can launch each required profile, trust, capability, failure, diagnostic, onboarding, migration, and privacy state without embedding real secrets or bypassing production safety decisions. 4. A smoke run on an available iOS Simulator and native macOS test destination produces xcresult bundles, step-named screenshots, extracted images, and snapshot diff artifacts on failure. 5. The task documents mandatory visual screenshot inspection for orientation, layout, content, and black-screen failures plus the separate named physical-device evidence contract.
