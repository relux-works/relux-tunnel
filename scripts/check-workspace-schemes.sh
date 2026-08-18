#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 XCODEBUILD_WORKSPACE_LIST" >&2
  exit 2
fi

workspace_list=$1
if [ ! -f "$workspace_list" ]; then
  echo "error: workspace list does not exist: $workspace_list" >&2
  exit 2
fi

actual_schemes=$(
  sed -n '/^[[:space:]]*Schemes:/,$p' "$workspace_list" |
    sed -n 's/^        \([^[:space:]].*\)$/\1/p' |
    LC_ALL=C sort
)
expected_schemes=$(cat <<'SCHEMES'
ReluxProxyMac
ReluxProxyMacTunnel
ReluxTunnelCore
ReluxTunnelHarness
relux-relay
relux-relay-protocol-test
SCHEMES
)
expected_schemes=$(printf '%s\n' "$expected_schemes" | LC_ALL=C sort)

if [ "$actual_schemes" != "$expected_schemes" ]; then
  echo "error: generated workspace scheme set does not match the active macOS graph" >&2
  echo "expected schemes:" >&2
  printf '%s\n' "$expected_schemes" >&2
  echo "actual schemes:" >&2
  printf '%s\n' "$actual_schemes" >&2
  exit 1
fi

echo "generated workspace scheme set is exact"
