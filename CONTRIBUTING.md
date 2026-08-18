# Contributing

## Before changing the product

1. Read `.spec/README.md` and `docs/current-state.md`.
2. Install the project-management tooling using `docs/project-management.md`.
3. Find or create the board element before implementation.
4. Use `task-board` for every `.task-board/` mutation; do not edit board files by
   hand.
5. Link the relevant `.spec/` documents to the task as precondition resources.
6. Do not implement VPN work until the generated plan has explicit user approval.

Changes that alter protocol, security, privacy, entitlements, routing, failure
modes, or supported platforms must update the corresponding specification and
`.spec/decisions.md`.

Native binary changes must also update `NativeDependencies/manifest.json`, be
reproducible from pinned source, regenerate third-party notices, and pass
`make validate-native`. Unpinned or runtime-downloaded native binaries are not
accepted.

## Development baseline

The current application requires macOS 14+, Xcode 15.3+, and Swift 5.10.

```sh
make core-test
make core-build
```

The planned multi-target VPN has additional gates in `.spec/validation.md`.
Passing current SwiftPM tests does not validate the future Network Extension.

This development Mac is build-only. Local build, compile, lint, unit,
integration, harness, and unsigned-provider tests are allowed. Never install a
system extension or containing app, save or remove a real VPN preference, call
`startVPNTunnel`, activate a provider, or mutate host routes or DNS here.
Physical macOS VPN work must be dependency-gated by `TASK-260819-25e1ys`, run
on a separately provisioned Mac, and pass
`scripts/physical-test-host-preflight.sh`. See
[`docs/build-host-safety.md`](docs/build-host-safety.md).

## Commits and pull requests

- Keep commits focused and do not mix generated build output with source/docs.
- Use the configured Ivan Oparin identity and signed commits for this repository.
- Never commit signing certificates, App Store Connect keys, SSH private keys,
  passphrases, provisioning secrets, tokens, or captured user traffic.
- Include board element IDs and human-readable names in implementation pull
  request descriptions once execution begins.
- Report verification commands and any untested physical-device requirement.
- Do not add AI attribution or `Co-Authored-By` trailers.

## Generated and local state

`.agents/`, `.claude/`, `.codex/`, `.local/`, `.temp/`, build output, and local
credentials are machine-local. `.task-board/`, `.planning/`, `.spec/`, and
durable `.research/` evidence are source-controlled.
