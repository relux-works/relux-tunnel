#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
task_output="$repo_root/.temp/TASK-260715-uyju7n"
products="$task_output/Products"
intermediates="$task_output/Intermediates"
derived_data="$task_output/DerivedData-validation"

mkdir -p "$task_output"
cd "$repo_root"

./scripts/generate-workspace.sh --clean

build_unsigned() {
  configuration=$1
  log_name=$(printf '%s' "$configuration" | tr '[:upper:]' '[:lower:]')
  xcodebuild \
    -workspace ReluxTunnel.xcworkspace \
    -scheme ReluxProxyMac \
    -configuration "$configuration" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    SYMROOT="$products" \
    OBJROOT="$intermediates" \
    build > "$task_output/credential-free-$log_name-build.log" 2>&1
}

build_unsigned Debug
build_unsigned Release

xcodebuild \
  -workspace ReluxTunnel.xcworkspace \
  -scheme ReluxProxyMac \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  SYMROOT="$products" \
  OBJROOT="$intermediates" \
  test > "$task_output/target-contract-tests.log" 2>&1

host="$products/Debug/ReluxProxyMac.app"
extensions="$host/Contents/Library/SystemExtensions"
provider="$extensions/works.relux.tunnel.mac.tunnel.systemextension"

test -d "$host"
test "$(find "$extensions" -mindepth 1 -maxdepth 1 -type d -name '*.systemextension' | wc -l | tr -d ' ')" -eq 1
test -d "$provider"
test "$(plutil -extract CFBundleIdentifier raw "$host/Contents/Info.plist")" = \
  'works.relux.tunnel.mac'
test "$(plutil -extract CFBundleIdentifier raw "$provider/Contents/Info.plist")" = \
  'works.relux.tunnel.mac.tunnel'
test "$(plutil -extract LSMinimumSystemVersion raw "$host/Contents/Info.plist")" = '15.0'
test "$(plutil -extract LSMinimumSystemVersion raw "$provider/Contents/Info.plist")" = '15.0'
test "$(plutil -extract CFBundleShortVersionString raw "$host/Contents/Info.plist")" = \
  "$(plutil -extract CFBundleShortVersionString raw "$provider/Contents/Info.plist")"
test "$(plutil -extract CFBundleVersion raw "$host/Contents/Info.plist")" = \
  "$(plutil -extract CFBundleVersion raw "$provider/Contents/Info.plist")"
provider_identifier=$(plutil -extract CFBundleIdentifier raw "$provider/Contents/Info.plist")
provider_module=$(printf '%s' "$provider_identifier" | tr '.-' '__')
test "$(/usr/libexec/PlistBuddy -c 'Print :NetworkExtension:NEProviderClasses:com.apple.networkextension.packet-tunnel' "$provider/Contents/Info.plist")" = \
  "$provider_module.PacketTunnelProvider"

if find "$extensions" -mindepth 1 -maxdepth 1 -type d ! -name '*.systemextension' | grep -q .; then
  echo "error: unexpected embedded item in SystemExtensions" >&2
  exit 1
fi

echo "macOS host/provider target validation passed"
