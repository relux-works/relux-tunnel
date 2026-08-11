#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROBE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
REPOSITORY_ROOT="$(cd "$PROBE_ROOT/../.." && pwd -P)"
TASK_ID="TASK-260715-9yp8to"
EXPECTED_HOST_ID="works.relux.tunnel.probe.mac"
EXPECTED_PROVIDER_ID="works.relux.tunnel.probe.mac.tunnel"
EXPECTED_PROVIDER_NAME="ReluxPacketTunnelProbeProvider.appex"
DEFAULT_ARCHIVE_APP="$REPOSITORY_ROOT/.temp/TASK-260715-1r0fxv/ReluxPacketTunnelProbe.xcarchive/Products/Applications/ReluxPacketTunnelProbe.app"
DEFAULT_INSTALLED_APP="/Applications/ReluxPacketTunnelProbe.app"
OUTPUT_ROOT="${PROBE_PHYSICAL_OUTPUT_ROOT:-$REPOSITORY_ROOT/.temp/$TASK_ID}"

usage() {
  cat <<'EOF'
usage:
  physical-gate-p0.sh preflight [archive-app]
  physical-gate-p0.sh exercise [installed-app] [cycles]
  physical-gate-p0.sh verify-log LOG CYCLES

Installation and removal are deliberately separate privileged operator steps.
This runner never invokes sudo, never changes VPN preferences except through
the accepted probe, and never records device IDs or signing credentials.
EOF
}

fail() {
  echo "FAIL: $*" >&2
  return 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true
}

event_count() {
  local log_path="$1"
  local event="$2"
  grep -F -c -- "$event" "$log_path" 2>/dev/null || true
}

count_probe_managers() {
  grep -F -c -- "[VPN:$EXPECTED_HOST_ID]" || true
}

wait_for_event_count() {
  local log_path="$1"
  local event="$2"
  local expected_count="$3"
  local timeout_seconds="$4"
  local deadline=$((SECONDS + timeout_seconds))

  while [ "$SECONDS" -lt "$deadline" ]; do
    if [ "$(event_count "$log_path" "$event")" -ge "$expected_count" ]; then
      return 0
    fi
    if grep -F -q -- "operation=failed" "$log_path" 2>/dev/null; then
      fail "probe reported operation=failed while waiting for $event"
      return 1
    fi
    sleep 0.2
  done
  fail "timed out waiting for event '$event' count $expected_count"
}

wait_for_no_provider_process() {
  local timeout_seconds="$1"
  local deadline=$((SECONDS + timeout_seconds))
  local pattern="$EXPECTED_PROVIDER_NAME/Contents/MacOS/ReluxPacketTunnelProbeProvider"

  while [ "$SECONDS" -lt "$deadline" ]; do
    if ! pgrep -f "$pattern" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  fail "provider process remained after the bounded stop window"
}

verify_lifecycle_log() {
  local log_path="$1"
  local cycles="$2"
  local event
  local required_events=(
    "configuration=reloaded-enabled"
    "provider=start-requested"
    "status=connected"
    "provider=response-v1-validated"
    "provider=stop-requested"
    "provider=stopped-cleanly"
    "lifecycle=started packet-forwarding=false"
    "message=v1-response packet-forwarding=false"
    "lifecycle=stopping outstanding-work=0"
    "lifecycle=stopped outstanding-work=0"
  )

  [ -f "$log_path" ] || fail "lifecycle log does not exist: $log_path"
  [ "$cycles" -ge 1 ] 2>/dev/null || fail "cycle count must be a positive integer"

  for event in "${required_events[@]}"; do
    if [ "$(event_count "$log_path" "$event")" -lt "$cycles" ]; then
      fail "event '$event' occurred fewer than $cycles times"
      return 1
    fi
  done
  if grep -F -q -- "operation=failed" "$log_path"; then
    fail "lifecycle log contains operation=failed"
    return 1
  fi
  echo "PASS: lifecycle log contains all required events for $cycles cycle(s)"
}

privacy_scan() {
  local path="$1"
  local finding=0

  if grep -E -i -q -- '(serial number|hardware uuid|provisioning udid|private key|password=|token=|secret=)' "$path"; then
    finding=1
  fi
  if grep -E -q -- '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}' "$path"; then
    finding=1
  fi
  if [ "$finding" -ne 0 ]; then
    fail "privacy scan found a prohibited credential or device-identity marker in $path"
    return 1
  fi
  echo "PASS: privacy scan found no credential or device-identity marker in $path"
}

record_profile_metadata() {
  local label="$1"
  local bundle_path="$2"
  local decoded="$3"

  security cms -D -i "$bundle_path/Contents/embedded.provisionprofile" > "$decoded"
  {
    echo "$label.profileUUID=$(plist_value "$decoded" UUID)"
    echo "$label.profileName=$(plist_value "$decoded" Name)"
    echo "$label.profilePlatform=$(plist_value "$decoded" Platform:0)"
    echo "$label.profileExpiration=$(plist_value "$decoded" ExpirationDate)"
    echo "$label.profileApplicationIdentifier=$(plist_value "$decoded" Entitlements:com.apple.application-identifier)"
  }
}

preflight() {
  local app_path="${1:-$DEFAULT_ARCHIVE_APP}"
  local provider_path="$app_path/Contents/PlugIns/$EXPECTED_PROVIDER_NAME"
  local metadata="$OUTPUT_ROOT/environment-and-bundle-metadata.txt"
  local requirements="$OUTPUT_ROOT/designated-requirements.txt"
  local inspection="$OUTPUT_ROOT/archive-inspection.log"
  local profile_temp
  local signing_class

  [ -d "$app_path" ] || fail "archive application does not exist: $app_path"
  [ -d "$provider_path" ] || fail "embedded provider does not exist: $provider_path"
  mkdir -p "$OUTPUT_ROOT"
  profile_temp="$(mktemp -d "${TMPDIR:-/tmp}/relux-p0-profiles.XXXXXX")"
  cleanup_preflight() {
    rm -rf "$profile_temp"
  }
  trap cleanup_preflight EXIT INT TERM

  "$SCRIPT_DIR/inspect-archive.sh" "$app_path" | tee "$inspection"
  signing_class="$(codesign -d --verbose=4 "$app_path" 2>&1 \
    | sed -n 's/^Authority=\([^:]*\):.*/\1/p' | head -n 1)"

  {
    echo "task=$TASK_ID"
    echo "timestampUTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "modelIdentifier=$(sysctl -n hw.model)"
    echo "architecture=$(uname -m)"
    echo "macOSProductVersion=$(sw_vers -productVersion)"
    echo "macOSBuildVersion=$(sw_vers -buildVersion)"
    echo "xcode=$(xcodebuild -version | tr '\n' ' ' | sed 's/ $//')"
    echo "sourceRevision=$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
    echo "sourceState=$(git -C "$REPOSITORY_ROOT" status --porcelain | if read -r _; then echo dirty; else echo clean; fi)"
    echo "signingIdentityClass=${signing_class:-unknown}"
    echo "hostBundleIdentifier=$(plist_value "$app_path/Contents/Info.plist" CFBundleIdentifier)"
    echo "hostBundleVersion=$(plist_value "$app_path/Contents/Info.plist" CFBundleVersion)"
    echo "hostShortVersion=$(plist_value "$app_path/Contents/Info.plist" CFBundleShortVersionString)"
    echo "providerBundleIdentifier=$(plist_value "$provider_path/Contents/Info.plist" CFBundleIdentifier)"
    echo "providerBundleVersion=$(plist_value "$provider_path/Contents/Info.plist" CFBundleVersion)"
    echo "providerShortVersion=$(plist_value "$provider_path/Contents/Info.plist" CFBundleShortVersionString)"
    record_profile_metadata host "$app_path" "$profile_temp/host.plist"
    record_profile_metadata provider "$provider_path" "$profile_temp/provider.plist"
  } > "$metadata"

  {
    echo "host:"
    codesign -d -r- "$app_path" 2>&1
    echo "provider:"
    codesign -d -r- "$provider_path" 2>&1
  } | sed -E 's/certificate leaf\[subject\.CN\] = "[^"]+"/certificate leaf[subject.CN] = "[REDACTED SUBJECT]"/g' \
    > "$requirements"

  privacy_scan "$metadata"
  privacy_scan "$requirements"
  privacy_scan "$inspection"
  cleanup_preflight
  trap - EXIT INT TERM
  echo "PASS: physical Gate P0 preflight evidence recorded under $OUTPUT_ROOT"
}

exercise() {
  local app_path="${1:-$DEFAULT_INSTALLED_APP}"
  local cycles="${2:-10}"
  local app_binary="$app_path/Contents/MacOS/ReluxPacketTunnelProbe"
  local raw_log="$OUTPUT_ROOT/lifecycle-unified.log"
  local summary="$OUTPUT_ROOT/lifecycle-summary.txt"
  local log_pid=""
  local app_pid=""
  local cycle
  local manager_count
  local timeout_seconds="${PROBE_CYCLE_TIMEOUT_SECONDS:-180}"

  [ -x "$app_binary" ] || fail "installed probe executable does not exist: $app_binary"
  [[ "$cycles" =~ ^[1-9][0-9]*$ ]] || fail "cycles must be a positive integer"
  mkdir -p "$OUTPUT_ROOT"
  : > "$raw_log"
  : > "$summary"

  cleanup_exercise() {
    if [ -n "$app_pid" ] && kill -0 "$app_pid" >/dev/null 2>&1; then
      kill -TERM "$app_pid" >/dev/null 2>&1 || true
      wait "$app_pid" 2>/dev/null || true
    fi
    if [ -n "$log_pid" ] && kill -0 "$log_pid" >/dev/null 2>&1; then
      kill -TERM "$log_pid" >/dev/null 2>&1 || true
      wait "$log_pid" 2>/dev/null || true
    fi
  }
  trap cleanup_exercise EXIT INT TERM

  /usr/bin/log stream --style compact --level info \
    --predicate "subsystem == '$EXPECTED_HOST_ID' OR subsystem == '$EXPECTED_PROVIDER_ID'" \
    >> "$raw_log" 2>&1 &
  log_pid=$!
  sleep 1

  for ((cycle = 1; cycle <= cycles; cycle++)); do
    "$app_binary" --run-probe >/dev/null 2>&1 &
    app_pid=$!
    wait_for_event_count "$raw_log" "provider=stopped-cleanly" "$cycle" "$timeout_seconds"
    wait_for_event_count "$raw_log" "lifecycle=stopped outstanding-work=0" "$cycle" 20
    kill -TERM "$app_pid" >/dev/null 2>&1 || true
    wait "$app_pid" 2>/dev/null || true
    app_pid=""
    wait_for_no_provider_process 20
    printf 'cycle=%d result=pass hostTerminated=true providerProcessCount=0\n' "$cycle" \
      | tee -a "$summary"
  done

  cleanup_exercise
  trap - EXIT INT TERM
  log_pid=""
  verify_lifecycle_log "$raw_log" "$cycles" | tee -a "$summary"

  manager_count="$(scutil --nc list | count_probe_managers)"
  echo "managerCount=$manager_count" | tee -a "$summary"
  [ "$manager_count" -eq 1 ] || fail "expected exactly one saved probe manager, found $manager_count"
  wait_for_no_provider_process 5
  privacy_scan "$raw_log" | tee -a "$summary"
  privacy_scan "$summary"
  echo "PASS: $cycles physical lifecycle cycle(s), host termination, one manager, and no provider process"
}

main() {
  local command="${1:-}"
  case "$command" in
    preflight)
      shift
      preflight "$@"
      ;;
    exercise)
      shift
      exercise "$@"
      ;;
    verify-log)
      [ "$#" -eq 3 ] || { usage; return 2; }
      verify_lifecycle_log "$2" "$3"
      ;;
    *)
      usage
      return 2
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
