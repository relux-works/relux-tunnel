# Manual validation and approvals logbook

## 2026-08-19 — Build-host VPN safety boundary

- The prior disposable P0 probe had a reusable local `exercise` path that
  starts a real packet-tunnel manager. Its historical task is already accepted,
  so it was not reopened; the runner itself is now guarded before physical
  preflight or exercise.
- The current development Mac is registered build-only by a one-way
  `IOPlatformUUID` fingerprint. Raw hardware identity is not persisted or
  printed.
- Nineteen active macOS network-mutating physical validation tasks across
  M1–M5 were linked directly to dedicated-host gate `TASK-260819-25e1ys`.
  M0 CLI harness measurements remain local-safe because they do not install,
  save, activate, start, route, or change DNS through a system VPN.
- Independent review found that `RELUX_BUILD_ONLY_HOSTS_FILE=/dev/null` could
  replace the production denylist. The production entrypoint now always uses
  the repository-owned `config/build-only-hosts.sha256`; synthetic denylist
  injection remains limited to the pure validation function and tests. A
  regression reproduces the override attempt and requires build-host rejection.
