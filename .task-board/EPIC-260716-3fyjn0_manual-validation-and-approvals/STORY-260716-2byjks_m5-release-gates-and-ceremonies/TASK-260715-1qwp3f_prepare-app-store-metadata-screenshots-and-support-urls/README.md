# Prepare App Store metadata, screenshots, and support URLs

## Description
Produce the release-specific App Store listing and review metadata that accurately describes a self-hosted SSH VPN, uses verified screenshots, links working policy and support pages, and avoids unsupported privacy, anonymity, performance, region, or capability claims.

## Scope
In scope: app name and subtitle as approved, description, keywords, promotional text if used, categories, age rating inputs, copyright, version release notes, support and marketing URLs, privacy URL, screenshots for required device classes and launch locales, captions or alt context where supported, full and degraded UI, system VPN behavior, accessibility and localization review, export of metadata values, and evidence. Out of scope: fabricated endorsements, traffic or user screenshots, production hostnames, unsupported translations, competitor claims, guaranteed anonymity, worldwide availability before legal approval, and App Store upload before package audit.

## Acceptance Criteria
1. Every product and privacy claim maps to implemented behavior, accepted release evidence, and approved copy; the listing explains that users supply their own SSH host and Relux Works is not the exit provider. 2. Required URLs are publicly reachable, secure, accessible, region appropriate, and semantically consistent with in-app disclosure, App Privacy answers, support operations, and review notes. 3. Screenshots come from the exact candidate or an identical reviewed UI state, cover required device classes and locales, contain no personal or production data, and pass visual, localization, and accessibility inspection. 4. Metadata captures exact submitted values, locale variants, owners, approval dates, and App Store Connect field mapping in a TASK-ID-scoped artifact. 5. Broken URLs, stale screenshot, unsupported claim, private data, missing locale or device class, region conflict, or copy-version mismatch blocks the submission package.
