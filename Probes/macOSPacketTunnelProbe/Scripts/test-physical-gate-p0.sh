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

echo "PASS: physical Gate P0 runner parser and privacy tests"
