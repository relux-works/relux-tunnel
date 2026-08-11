#!/bin/bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
INSPECTOR="$SCRIPT_DIR/inspect-archive.sh"
FAILURES=0

if [ "$#" -ne 1 ]; then
  echo "usage: $0 /path/to/ReluxPacketTunnelProbe.app" >&2
  exit 2
fi

SOURCE_APP="$1"
DRIFT_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/relux-probe-drift.XXXXXX")"

cleanup() {
  case "$DRIFT_TEMP" in
    "${TMPDIR:-/tmp}"/relux-probe-drift.*) rm -rf "$DRIFT_TEMP" ;;
    *) echo "refusing to clean unexpected drift-test path" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

expect_drift() {
  name="$1"
  expected="$2"
  app="$3"
  log="$DRIFT_TEMP/$name.log"
  if "$INSPECTOR" "$app" > "$log" 2>&1; then
    echo "FAIL: $name drift was accepted" >&2
    FAILURES=$((FAILURES + 1))
  elif grep -Fq "$expected" "$log"; then
    echo "PASS: $name drift rejected"
  else
    echo "FAIL: $name failed without expected inspection evidence" >&2
    sed -n '1,220p' "$log" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

if ! "$INSPECTOR" "$SOURCE_APP" >/dev/null; then
  echo "error: baseline app does not pass inspection" >&2
  exit 2
fi

case_app="$DRIFT_TEMP/identifier/ReluxPacketTunnelProbe.app"
mkdir -p "$(dirname "$case_app")"
ditto "$SOURCE_APP" "$case_app"
/usr/libexec/PlistBuddy -c \
  "Set :CFBundleIdentifier works.relux.tunnel.probe.mac.drift" \
  "$case_app/Contents/Info.plist"
expect_drift identifier "host bundle identifier is approved" "$case_app"

case_app="$DRIFT_TEMP/capability/ReluxPacketTunnelProbe.app"
mkdir -p "$(dirname "$case_app")"
ditto "$SOURCE_APP" "$case_app"
case_provider="$case_app/Contents/PlugIns/ReluxPacketTunnelProbeProvider.appex"
drift_entitlements="$DRIFT_TEMP/capability/provider.entitlements"
codesign -d --entitlements :- "$case_provider" > "$drift_entitlements" 2>/dev/null
/usr/libexec/PlistBuddy -c \
  "Set :com.apple.developer.networking.networkextension:0 packet-tunnel-provider-systemextension" \
  "$drift_entitlements"
codesign --force --sign - --entitlements "$drift_entitlements" "$case_provider" >/dev/null 2>&1
expect_drift capability "provider target network-extension entitlement is exact" "$case_app"

case_app="$DRIFT_TEMP/host-sandbox/ReluxPacketTunnelProbe.app"
mkdir -p "$(dirname "$case_app")"
ditto "$SOURCE_APP" "$case_app"
drift_entitlements="$DRIFT_TEMP/host-sandbox/host.entitlements"
codesign -d --entitlements :- "$case_app" > "$drift_entitlements" 2>/dev/null
/usr/libexec/PlistBuddy -c \
  "Delete :com.apple.security.app-sandbox" \
  "$drift_entitlements"
codesign --force --sign - --entitlements "$drift_entitlements" "$case_app" >/dev/null 2>&1
expect_drift host-sandbox "host signed product requires App Sandbox" "$case_app"

case_app="$DRIFT_TEMP/provider-sandbox/ReluxPacketTunnelProbe.app"
mkdir -p "$(dirname "$case_app")"
ditto "$SOURCE_APP" "$case_app"
case_provider="$case_app/Contents/PlugIns/ReluxPacketTunnelProbeProvider.appex"
drift_entitlements="$DRIFT_TEMP/provider-sandbox/provider.entitlements"
codesign -d --entitlements :- "$case_provider" > "$drift_entitlements" 2>/dev/null
/usr/libexec/PlistBuddy -c \
  "Delete :com.apple.security.app-sandbox" \
  "$drift_entitlements"
codesign --force --sign - --entitlements "$drift_entitlements" "$case_provider" >/dev/null 2>&1
expect_drift provider-sandbox "provider signed product requires App Sandbox" "$case_app"

case_app="$DRIFT_TEMP/app-groups/ReluxPacketTunnelProbe.app"
mkdir -p "$(dirname "$case_app")"
ditto "$SOURCE_APP" "$case_app"
drift_entitlements="$DRIFT_TEMP/app-groups/host.entitlements"
codesign -d --entitlements :- "$case_app" > "$drift_entitlements" 2>/dev/null
/usr/libexec/PlistBuddy -c \
  "Add :com.apple.security.application-groups array" \
  "$drift_entitlements"
/usr/libexec/PlistBuddy -c \
  "Add :com.apple.security.application-groups:0 string 262RZ595FP.forbidden" \
  "$drift_entitlements"
codesign --force --sign - --entitlements "$drift_entitlements" "$case_app" >/dev/null 2>&1
expect_drift app-groups "host target has no App Groups entitlement" "$case_app"

case_app="$DRIFT_TEMP/keychain-sharing/ReluxPacketTunnelProbe.app"
mkdir -p "$(dirname "$case_app")"
ditto "$SOURCE_APP" "$case_app"
case_provider="$case_app/Contents/PlugIns/ReluxPacketTunnelProbeProvider.appex"
drift_entitlements="$DRIFT_TEMP/keychain-sharing/provider.entitlements"
codesign -d --entitlements :- "$case_provider" > "$drift_entitlements" 2>/dev/null
/usr/libexec/PlistBuddy -c \
  "Add :keychain-access-groups array" \
  "$drift_entitlements"
/usr/libexec/PlistBuddy -c \
  "Add :keychain-access-groups:0 string 262RZ595FP.forbidden" \
  "$drift_entitlements"
codesign --force --sign - --entitlements "$drift_entitlements" "$case_provider" >/dev/null 2>&1
expect_drift keychain-sharing "provider target has no Keychain Sharing entitlement" "$case_app"

case_app="$DRIFT_TEMP/profile/ReluxPacketTunnelProbe.app"
mkdir -p "$(dirname "$case_app")"
ditto "$SOURCE_APP" "$case_app"
cp \
  "$case_app/Contents/PlugIns/ReluxPacketTunnelProbeProvider.appex/Contents/embedded.provisionprofile" \
  "$case_app/Contents/embedded.provisionprofile"
expect_drift profile "host profile UUID is approved" "$case_app"

case_app="$DRIFT_TEMP/nested/ReluxPacketTunnelProbe.app"
mkdir -p "$(dirname "$case_app")"
ditto "$SOURCE_APP" "$case_app"
ditto \
  "$case_app/Contents/PlugIns/ReluxPacketTunnelProbeProvider.appex" \
  "$case_app/Contents/PlugIns/UnexpectedProvider.appex"
expect_drift nested "host embeds exactly one provider" "$case_app"

case_app="$DRIFT_TEMP/signature/ReluxPacketTunnelProbe.app"
mkdir -p "$(dirname "$case_app")"
ditto "$SOURCE_APP" "$case_app"
printf '\0' >> \
  "$case_app/Contents/PlugIns/ReluxPacketTunnelProbeProvider.appex/Contents/MacOS/ReluxPacketTunnelProbeProvider"
expect_drift signature "provider signature verifies" "$case_app"

if [ "$FAILURES" -ne 0 ]; then
  echo "Inspector drift tests failed: $FAILURES" >&2
  exit 1
fi

echo "Inspector drift tests passed."
