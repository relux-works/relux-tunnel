# Inventory the legacy project and migration invariants

## Description
Create the authoritative current-state inventory for migrating from the macOS SwiftPM menu-bar app to the generated multi-target workspace. Identify every existing build, test, configuration, default, packaging, signing, and release behavior that must remain reproducible or be explicitly retired later.

## Scope
In scope: Package.swift, Sources and Tests, system SSH invocation, AppStorage defaults, manual SOCKS behavior, Info.plist, Makefile, app and DMG scripts, CI and release workflows, signing assumptions, artifact names, documentation, and release-history compatibility. Out of scope: changing any source or workflow, deciding the future product UX, implementing targets, or retiring the existing app.

## Acceptance Criteria
1. A TASK-ID-scoped inventory names each current target, source area, test suite, script, workflow, artifact, signing mode, default, and user-visible behavior with its verification command. 2. Migration invariants distinguish must-preserve M0 behavior from later explicit retirement decisions. 3. Known conflicts between an unsandboxed system-SSH app and sandboxed or entitled future targets are documented without proposing hidden compatibility hacks. 4. The inventory identifies ownership and destination for existing tests, release assets, profile defaults, and documentation. 5. A reviewer can use the artifact as a regression checklist without rereading the whole repository.
