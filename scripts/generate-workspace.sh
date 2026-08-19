#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

python3 scripts/relay_asset_manifest.py generate

expected_tuist_version=4.202.5
configured_tuist_version=$(sed -n 's/^tuist = "\([^"]*\)"$/\1/p' mise.toml)

if [ "$configured_tuist_version" != "$expected_tuist_version" ]; then
  echo "error: mise.toml must pin Tuist $expected_tuist_version" >&2
  exit 1
fi

if ! command -v mise >/dev/null 2>&1; then
  echo "error: mise is required; install it before generating the workspace" >&2
  exit 1
fi

mise install tuist@"$expected_tuist_version"
actual_tuist_version=$(mise exec -- tuist version | sed -n 's/^\([0-9][0-9.]*\).*$/\1/p' | head -n 1)
if [ "$actual_tuist_version" != "$expected_tuist_version" ]; then
  echo "error: expected Tuist $expected_tuist_version, got ${actual_tuist_version:-unknown}" >&2
  exit 1
fi

if [ "${1:-}" = "--clean" ]; then
  rm -rf "$repo_root/ReluxTunnel.xcworkspace" "$repo_root/ReluxTunnelApp.xcodeproj"
elif [ "$#" -ne 0 ]; then
  echo "usage: $0 [--clean]" >&2
  exit 2
fi

mise exec -- tuist generate --no-open
