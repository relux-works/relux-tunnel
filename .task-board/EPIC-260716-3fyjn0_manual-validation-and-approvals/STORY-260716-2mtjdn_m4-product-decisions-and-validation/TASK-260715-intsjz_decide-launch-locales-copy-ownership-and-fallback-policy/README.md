# Decide launch locales, copy ownership, and fallback policy

## Description
Close the unspecified launch-localization boundary before implementation acceptance. Record which locales ship, who owns source and translated privacy/security copy, how translations are reviewed, and what unsupported locales see.

## Scope
In scope: source language, launch locale list, English-only baseline option, system-locale behavior, fallback, plural/date/number formatting, privacy/security terminology review, translator context, pseudo-localization, text expansion, right-to-left readiness or explicit deferral, missing-key policy, versioning, accessibility pronunciation, approval roles, and release handoff. Out of scope: producing translations without approved owners, regional licensing/storefront decisions, implementation, and public policy hosting.

## Acceptance Criteria
1. A TASK-ID-scoped decision names the exact launch locales and fallback chain; if English-only is selected, all strings still use localization resources and unsupported locales fall back predictably. 2. Source-copy, translation, privacy/legal, accessibility, product, and release owners plus review/update triggers are explicit. 3. Rules cover variables, plurals, dates/numbers, SSH/security terms, link targets, missing keys, stale translations, right-to-left handling, and copy-version parity. 4. Pseudo-localization, long-text expansion, locale launch, screenshot, and accessibility acceptance rows are defined for both platforms. 5. Approval or the precise blocking choice remains recorded and downstream localization/UI-test/M5 tasks are identified without guessing translations.
