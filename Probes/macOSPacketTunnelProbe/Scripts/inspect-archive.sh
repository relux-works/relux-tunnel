#!/bin/bash

set -u
set -o pipefail

EXPECTED_TEAM="262RZ595FP"
EXPECTED_HOST_ID="works.relux.tunnel.probe.mac"
EXPECTED_PROVIDER_ID="works.relux.tunnel.probe.mac.tunnel"
EXPECTED_HOST_PROFILE="c0a3cd4e-77c8-475e-98e0-6deec8269810"
EXPECTED_PROVIDER_PROFILE="ef64bcae-00ac-458f-94dc-45834429fe80"
EXPECTED_PROVIDER_NAME="ReluxPacketTunnelProbeProvider.appex"
FAILURES=0

if [ "$#" -ne 1 ]; then
  echo "usage: $0 /path/to/ReluxPacketTunnelProbe.app" >&2
  exit 2
fi

PROBE_APP="$1"
PROBE_PROVIDER="$PROBE_APP/Contents/PlugIns/$EXPECTED_PROVIDER_NAME"
INSPECTION_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/relux-probe-inspection.XXXXXX")"

cleanup() {
  case "$INSPECTION_TEMP" in
    "${TMPDIR:-/tmp}"/relux-probe-inspection.*) rm -rf "$INSPECTION_TEMP" ;;
    *) echo "refusing to clean unexpected inspection path" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

pass() {
  echo "PASS: $*"
}

fail() {
  echo "FAIL: $*" >&2
  FAILURES=$((FAILURES + 1))
}

expect_equal() {
  actual="$1"
  expected="$2"
  description="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$description"
  else
    fail "$description (expected '$expected', found '${actual:-<missing>}')"
  fi
}

expect_absent() {
  plist="$1"
  key="$2"
  description="$3"
  if /usr/libexec/PlistBuddy -c "Print :$key" "$plist" >/dev/null 2>&1; then
    fail "$description"
  else
    pass "$description"
  fi
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true
}

inspect_signature() {
  label="$1"
  target="$2"
  expected_identifier="$3"
  metadata="$INSPECTION_TEMP/$label-signature.txt"
  entitlements="$INSPECTION_TEMP/$label-entitlements.plist"

  if codesign --verify --strict --verbose=2 "$target" >/dev/null 2>&1; then
    pass "$label signature verifies"
  else
    fail "$label signature verifies"
  fi
  codesign -d --verbose=4 "$target" > /dev/null 2> "$metadata" || true
  expect_equal "$(sed -n 's/^Identifier=//p' "$metadata" | head -n 1)" \
    "$expected_identifier" "$label signature identifier is approved"
  expect_equal "$(sed -n 's/^TeamIdentifier=//p' "$metadata" | head -n 1)" \
    "$EXPECTED_TEAM" "$label signature team is approved"
  if sed -n 's/^Authority=//p' "$metadata" | head -n 1 | grep -q '^Apple Development:'; then
    pass "$label signature uses Apple Development"
  else
    fail "$label signature uses Apple Development"
  fi

  if codesign -d --entitlements :- "$target" > "$entitlements" 2>/dev/null \
    && plutil -lint "$entitlements" >/dev/null; then
    pass "$label signed entitlements decode"
  else
    fail "$label signed entitlements decode"
  fi
  expect_equal "$(plist_value "$entitlements" com.apple.application-identifier)" \
    "$EXPECTED_TEAM.$expected_identifier" "$label signed application identifier is approved"
  expect_equal "$(plist_value "$entitlements" com.apple.developer.team-identifier)" \
    "$EXPECTED_TEAM" "$label signed team entitlement is approved"
  expect_equal \
    "$(plist_value "$entitlements" com.apple.developer.networking.networkextension:0)" \
    "packet-tunnel-provider" "$label target network-extension entitlement is exact"
  if /usr/libexec/PlistBuddy -c \
    "Print :com.apple.developer.networking.networkextension:1" \
    "$entitlements" >/dev/null 2>&1; then
    fail "$label target has no extra network-extension capability"
  else
    pass "$label target has no extra network-extension capability"
  fi
  expect_absent "$entitlements" com.apple.security.application-groups \
    "$label target has no App Groups entitlement"
  expect_absent "$entitlements" keychain-access-groups \
    "$label target has no Keychain Sharing entitlement"
}

inspect_profile() {
  label="$1"
  target="$2"
  expected_identifier="$3"
  expected_uuid="$4"
  profile="$target/Contents/embedded.provisionprofile"
  decoded="$INSPECTION_TEMP/$label-profile.plist"

  if [ -f "$profile" ] && security cms -D -i "$profile" > "$decoded" 2>/dev/null; then
    pass "$label embedded profile decodes"
  else
    fail "$label embedded profile decodes"
  fi
  expect_equal "$(plist_value "$decoded" UUID)" "$expected_uuid" \
    "$label profile UUID is approved"
  expect_equal "$(plist_value "$decoded" TeamIdentifier:0)" "$EXPECTED_TEAM" \
    "$label profile team is approved"
  expect_equal "$(plist_value "$decoded" Platform:0)" "OSX" \
    "$label profile platform is macOS"
  expect_equal \
    "$(plist_value "$decoded" Entitlements:com.apple.application-identifier)" \
    "$EXPECTED_TEAM.$expected_identifier" "$label profile application identifier is approved"
  profile_capabilities="$(plist_value \
    "$decoded" Entitlements:com.apple.developer.networking.networkextension)"
  if printf '%s\n' "$profile_capabilities" | grep -qx '    packet-tunnel-provider'; then
    pass "$label profile authorizes packet-tunnel-provider"
  else
    fail "$label profile authorizes packet-tunnel-provider"
  fi
  if printf '%s\n' "$profile_capabilities" | grep -q 'packet-tunnel-provider-systemextension'; then
    fail "$label profile excludes system-extension capability drift"
  else
    pass "$label profile excludes system-extension capability drift"
  fi
  expect_absent "$decoded" Entitlements:com.apple.security.application-groups \
    "$label profile has no App Groups capability"
}

if [ ! -d "$PROBE_APP" ]; then
  echo "error: probe app does not exist: $PROBE_APP" >&2
  exit 2
fi

expect_equal "$(plist_value "$PROBE_APP/Contents/Info.plist" CFBundleIdentifier)" \
  "$EXPECTED_HOST_ID" "host bundle identifier is approved"

provider_count="$(find "$PROBE_APP/Contents/PlugIns" -mindepth 1 -maxdepth 1 \
  -type d -name '*.appex' 2>/dev/null | wc -l | tr -d ' ')"
expect_equal "$provider_count" "1" "host embeds exactly one provider"
if [ -d "$PROBE_PROVIDER" ]; then
  pass "host embeds the expected provider product"
else
  fail "host embeds the expected provider product"
fi
expect_equal "$(plist_value "$PROBE_PROVIDER/Contents/Info.plist" CFBundleIdentifier)" \
  "$EXPECTED_PROVIDER_ID" "provider bundle identifier is approved"
expect_equal \
  "$(plist_value "$PROBE_PROVIDER/Contents/Info.plist" NSExtension:NSExtensionPointIdentifier)" \
  "com.apple.networkextension.packet-tunnel" "provider extension point is packet tunnel"

unexpected_nested="$(find "$PROBE_APP/Contents" -type d \
  \( -name '*.appex' -o -name '*.framework' -o -name '*.xpc' \) \
  ! -path "$PROBE_PROVIDER" 2>/dev/null | wc -l | tr -d ' ')"
expect_equal "$unexpected_nested" "0" "host has no unexpected nested code"

if codesign --verify --deep --strict --verbose=2 "$PROBE_APP" >/dev/null 2>&1; then
  pass "nested-code signature verification succeeds"
else
  fail "nested-code signature verification succeeds"
fi

expect_equal "$(lipo -archs "$PROBE_APP/Contents/MacOS/ReluxPacketTunnelProbe" 2>/dev/null)" \
  "arm64" "host architecture is Apple silicon only"
expect_equal \
  "$(lipo -archs \
    "$PROBE_PROVIDER/Contents/MacOS/ReluxPacketTunnelProbeProvider" 2>/dev/null)" \
  "arm64" "provider architecture is Apple silicon only"

inspect_signature host "$PROBE_APP" "$EXPECTED_HOST_ID"
inspect_signature provider "$PROBE_PROVIDER" "$EXPECTED_PROVIDER_ID"
inspect_profile host "$PROBE_APP" "$EXPECTED_HOST_ID" "$EXPECTED_HOST_PROFILE"
inspect_profile provider "$PROBE_PROVIDER" "$EXPECTED_PROVIDER_ID" \
  "$EXPECTED_PROVIDER_PROFILE"

if [ "$FAILURES" -ne 0 ]; then
  echo "Inspection failed with $FAILURES drift finding(s)." >&2
  exit 1
fi

echo "Inspection passed: approved host/provider signatures, profiles, nesting, and entitlements."
