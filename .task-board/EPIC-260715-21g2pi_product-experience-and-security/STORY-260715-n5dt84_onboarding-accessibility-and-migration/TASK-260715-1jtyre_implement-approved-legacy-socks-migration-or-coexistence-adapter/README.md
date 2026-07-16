# Implement the approved legacy SOCKS migration or coexistence adapter

## Description
Implement only the behavior selected by the legacy SOCKS decision: isolated coexistence, explicit profile/default migration, or deliberate retirement messaging and cleanup. Preserve the legacy build/release path until the approved cutover condition is met.

## Scope
In scope: approved migration version, current AppStorage host/account/port reads, mapping to new profile drafts, unrepresentable configuration detection, user confirmation, idempotency, partial failure, rollback/downgrade markers, coexistence namespace isolation, retention/deletion prompts, release-channel gating, privacy-safe migration logs, and tests. Out of scope: inventing a decision, parsing arbitrary ~/.ssh/config unless explicitly approved, ProxyJump implementation, importing raw credentials silently, mutating past release artifacts, and VPN data-plane work.

## Acceptance Criteria
1. Behavior exactly matches the approved decision and migration matrix; unsupported legacy values remain unchanged and are explained rather than guessed or discarded. 2. Migration is explicit where user-visible/security-affecting, idempotent across relaunch/retry, atomic per profile, and recoverable after interruption or storage failure. 3. Coexisting products use distinct bundle, defaults, App Group, Keychain, process, artifact, and release namespaces; replacement/retirement preserves the approved rollback and support path. 4. No key/passphrase or arbitrary SSH config is copied to App Group/providerConfiguration/logs, and any generated new profile requires an explicit approved key/trust completion path. 5. Tests cover no legacy install, each legacy default combination, unrepresentable config, accept/cancel, interruption, repeated run, downgrade, deletion, coexistence, and clean legacy build verification.
