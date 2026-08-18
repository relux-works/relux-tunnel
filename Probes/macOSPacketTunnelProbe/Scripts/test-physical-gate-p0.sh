#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# The source path is resolved dynamically so the test can run from any cwd.
# shellcheck disable=SC1091
source "$SCRIPT_DIR/physical-gate-p0.sh"

TEST_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/relux-p0-runner-tests.XXXXXX")"
trap 'rm -rf "$TEST_TEMP"' EXIT INT TERM

complete_log="$TEST_TEMP/complete.log"
missing_log="$TEST_TEMP/missing.log"
failed_log="$TEST_TEMP/failed.log"

for _ in 1 2; do
  cat >> "$complete_log" <<'EOF'
configuration=reloaded-enabled
provider=start-requested
status=connected
provider=response-v1-validated
provider=stop-requested
provider=stopped-cleanly
lifecycle=started packet-forwarding=false
message=v1-response packet-forwarding=false
lifecycle=stopping outstanding-work=0
lifecycle=stopped outstanding-work=0
EOF
done

cp "$complete_log" "$missing_log"
sed -i '' '/provider=response-v1-validated/d' "$missing_log"
cp "$complete_log" "$failed_log"
echo "operation=failed" >> "$failed_log"

verify_lifecycle_log "$complete_log" 2 >/dev/null

if verify_lifecycle_log "$missing_log" 2 >/dev/null 2>&1; then
  echo "FAIL: incomplete lifecycle log was accepted" >&2
  exit 1
fi

if verify_lifecycle_log "$failed_log" 2 >/dev/null 2>&1; then
  echo "FAIL: explicit operation failure was accepted" >&2
  exit 1
fi

safe_metadata="$TEST_TEMP/safe-metadata.txt"
unsafe_metadata="$TEST_TEMP/unsafe-metadata.txt"
echo "modelIdentifier=Mac15,9" > "$safe_metadata"
echo "Serial Number: must-not-persist" > "$unsafe_metadata"
privacy_scan "$safe_metadata" >/dev/null
if privacy_scan "$unsafe_metadata" >/dev/null 2>&1; then
  echo "FAIL: unsafe metadata was accepted" >&2
  exit 1
fi

manager_listing="$TEST_TEMP/manager-listing.txt"
cat > "$manager_listing" <<'EOF'
Available network connection services in the current set (*=enabled):
* (Disconnected) UUID VPN (works.relux.tunnel.probe.mac) "Relux Disposable Packet Tunnel Probe" [VPN:works.relux.tunnel.probe.mac]
* (Disconnected) UUID VPN (works.relux.tunnel.probe.mac.tunnel) "Provider decoy" [VPN:works.relux.tunnel.probe.mac.tunnel]
EOF
if [ "$(count_probe_managers < "$manager_listing")" -ne 1 ]; then
  echo "FAIL: exact host manager was not counted once" >&2
  exit 1
fi

denylist="$TEST_TEMP/build-only-hosts.sha256"
build_fingerprint="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
remote_fingerprint="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
printf '%s current-development-mac\n' "$build_fingerprint" > "$denylist"

expect_preflight_failure() {
  if validate_physical_test_host "$@" >/dev/null 2>&1; then
    echo "FAIL: unsafe physical-test host configuration was accepted" >&2
    exit 1
  fi
}

expect_preflight_failure "" "dedicated-mac" "dedicated-mac" "$remote_fingerprint" "$denylist"
expect_preflight_failure "$REQUIRED_PHYSICAL_OPT_IN" "" "dedicated-mac" "$remote_fingerprint" "$denylist"
for target in localhost localhost. localhost.localdomain ip6-localhost ip6-loopback; do
  expect_preflight_failure \
    "$REQUIRED_PHYSICAL_OPT_IN" "$target" "$target" "$remote_fingerprint" "$denylist"
done
for target in 127.0.0.1 127.2.3.4 ::1 0:0:0:0:0:0:0:1; do
  expect_preflight_failure \
    "$REQUIRED_PHYSICAL_OPT_IN" "$target" "$target" "$remote_fingerprint" "$denylist"
done
expect_preflight_failure \
  "$REQUIRED_PHYSICAL_OPT_IN" "current-build-mac" "current-build-mac" \
  "$build_fingerprint" "$denylist"
expect_preflight_failure \
  "$REQUIRED_PHYSICAL_OPT_IN" "some-other-mac" "dedicated-mac" \
  "$remote_fingerprint" "$denylist"

validate_physical_test_host \
  "$REQUIRED_PHYSICAL_OPT_IN" "dedicated-mac.example.test" \
  $'dedicated-mac\ndedicated-mac.local' "$remote_fingerprint" "$denylist"

override_error="$TEST_TEMP/denylist-override.stderr"
if RELUX_BUILD_ONLY_HOSTS_FILE=/dev/null \
  RELUX_PHYSICAL_TEST_OPT_IN="$REQUIRED_PHYSICAL_OPT_IN" \
  RELUX_PHYSICAL_TEST_HOST="$(hostname -s)" \
  "$REPOSITORY_ROOT/scripts/physical-test-host-preflight.sh" \
  > /dev/null 2> "$override_error"; then
  echo "FAIL: caller-controlled denylist override bypassed the build-host guard" >&2
  exit 1
fi
if ! grep -F -q -- "this Mac is registered build-only" "$override_error"; then
  echo "FAIL: denylist override regression did not fail at the build-host guard" >&2
  exit 1
fi

for guarded_command in preflight exercise; do
  guard_error="$TEST_TEMP/$guarded_command.stderr"
  if env -u RELUX_PHYSICAL_TEST_OPT_IN -u RELUX_PHYSICAL_TEST_HOST \
    "$SCRIPT_DIR/physical-gate-p0.sh" "$guarded_command" \
    "$TEST_TEMP/does-not-exist.app" > /dev/null 2> "$guard_error"; then
    echo "FAIL: $guarded_command ran without dedicated-host opt-in" >&2
    exit 1
  fi
  if ! grep -F -q -- "set RELUX_PHYSICAL_TEST_OPT_IN" "$guard_error"; then
    echo "FAIL: $guarded_command did not fail at the host-safety guard" >&2
    exit 1
  fi
done

echo "PASS: physical Gate P0 parser, privacy, and build-host preflight tests"
