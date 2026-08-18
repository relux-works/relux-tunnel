#!/bin/bash

set -euo pipefail

PREFLIGHT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PREFLIGHT_REPOSITORY_ROOT="$(cd "$PREFLIGHT_SCRIPT_DIR/.." && pwd -P)"
BUILD_ONLY_HOSTS_FILE="$PREFLIGHT_REPOSITORY_ROOT/config/build-only-hosts.sha256"
REQUIRED_PHYSICAL_OPT_IN="dedicated-mac-only"

physical_preflight_fail() {
  echo "FAIL: $*" >&2
  return 1
}

normalize_host_name() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[.]$//'
}

is_loopback_host() {
  local host
  host="$(normalize_host_name "$1")"
  case "$host" in
    localhost|localhost.localdomain|ip6-localhost|ip6-loopback|::1|0:0:0:0:0:0:0:1)
      return 0
      ;;
    127.*)
      return 0
      ;;
  esac
  return 1
}

current_host_names() {
  {
    hostname 2>/dev/null || true
    hostname -s 2>/dev/null || true
    scutil --get LocalHostName 2>/dev/null || true
    scutil --get HostName 2>/dev/null || true
  } | sed '/^[[:space:]]*$/d'
}

current_machine_fingerprint() {
  local platform_uuid
  platform_uuid="$(ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null \
    | awk -F\" '/IOPlatformUUID/{print $(NF-1); exit}')"
  if [ -z "$platform_uuid" ]; then
    physical_preflight_fail "cannot read this Mac's platform identity"
    return 1
  fi
  printf '%s' "$platform_uuid" | shasum -a 256 | awk '{print $1}'
}

validate_physical_test_host() {
  local opt_in="$1"
  local configured_host="$2"
  local runtime_host_names="$3"
  local runtime_fingerprint="$4"
  local denylist_path="$5"
  local normalized_target
  local candidate
  local host_matches=false

  if [ "$opt_in" != "$REQUIRED_PHYSICAL_OPT_IN" ]; then
    physical_preflight_fail \
      "set RELUX_PHYSICAL_TEST_OPT_IN=$REQUIRED_PHYSICAL_OPT_IN explicitly"
    return 1
  fi
  if [ -z "$configured_host" ]; then
    physical_preflight_fail "RELUX_PHYSICAL_TEST_HOST must name the dedicated Mac"
    return 1
  fi
  if is_loopback_host "$configured_host"; then
    physical_preflight_fail "loopback and localhost targets are prohibited"
    return 1
  fi
  if [ ! -r "$denylist_path" ]; then
    physical_preflight_fail "build-only host denylist is unavailable: $denylist_path"
    return 1
  fi
  if ! printf '%s' "$runtime_fingerprint" | grep -Eq '^[[:xdigit:]]{64}$'; then
    physical_preflight_fail "runtime host fingerprint is unavailable or malformed"
    return 1
  fi

  if awk -v fingerprint="$runtime_fingerprint" \
    '$1 == fingerprint { found = 1 } END { exit(found ? 0 : 1) }' "$denylist_path"; then
    physical_preflight_fail \
      "this Mac is registered build-only; physical VPN validation is prohibited"
    return 1
  fi

  normalized_target="$(normalize_host_name "$configured_host")"
  while IFS= read -r candidate; do
    candidate="$(normalize_host_name "$candidate")"
    if [ "$normalized_target" = "$candidate" ] \
      || [ "${normalized_target%%.*}" = "${candidate%%.*}" ]; then
      host_matches=true
      break
    fi
  done <<EOF
$runtime_host_names
EOF

  if [ "$host_matches" != true ]; then
    physical_preflight_fail \
      "configured target does not identify the Mac executing the physical runner"
    return 1
  fi
}

require_dedicated_physical_test_host() {
  local names
  local fingerprint
  names="$(current_host_names)"
  fingerprint="$(current_machine_fingerprint)"
  validate_physical_test_host \
    "${RELUX_PHYSICAL_TEST_OPT_IN:-}" \
    "${RELUX_PHYSICAL_TEST_HOST:-}" \
    "$names" \
    "$fingerprint" \
    "$BUILD_ONLY_HOSTS_FILE"
  echo "PASS: dedicated physical-test host identity accepted"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  require_dedicated_physical_test_host
fi
