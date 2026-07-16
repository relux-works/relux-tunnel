# Add profile, key-storage, and trust-boundary tests

## Description
Create the automated non-UI suite proving profile persistence and credential boundaries across containing apps, App Group storage, provider reads, Keychain access groups, lifecycle races, and cleanup. Use synthetic keys only and scan all produced artifacts for prohibited data.

## Scope
In scope: repository unit tests, schema/generation golden vectors, atomic and concurrent writes, corruption and upgrade, Keychain adapter tests, wrong-group rejection, import/generation service integration, reference-aware deletion, provider loader/resolver compatibility, entitlement inspection, privacy-safe errors/logs, repeated cycles, and artifact secret scanning. Out of scope: UI interaction, production credentials, live SSH servers beyond existing M1 fixtures, App Store signing, and performance tuning.

## Acceptance Criteria
1. Tests prove atomic valid profile generations across create/edit/select/delete, relaunch, corruption, concurrent writers, schema upgrade, and active-generation retention. 2. Synthetic key/passphrase fixtures are accessible only through approved app/extension entitlements and wrong-group, App Group, providerConfiguration, log, and diagnostic paths contain no raw secret. 3. Import, generation, opaque-reference resolution, passphrase policy, duplicates, missing items, ref-count deletion, and cleanup are covered through production service composition. 4. Repeated create/import/publish/delete cycles return files, Keychain items, buffers, tasks, observers, and temporary artifacts to baseline. 5. The task publishes exact test commands, entitlement evidence, and a redacted TASK-ID-scoped result without secret fixture content.
