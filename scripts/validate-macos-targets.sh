#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
task_output="$repo_root/.temp/TASK-260715-uyju7n"
products="$task_output/Products"
intermediates="$task_output/Intermediates"
derived_data="$task_output/DerivedData-validation"

mkdir -p "$task_output"
cd "$repo_root"

./scripts/generate-workspace.sh --clean

build_unsigned() {
  scheme=$1
  configuration=$2
  log_name=$(printf '%s-%s' "$scheme" "$configuration" | tr '[:upper:]' '[:lower:]')
  xcodebuild \
    -workspace ReluxTunnel.xcworkspace \
    -scheme "$scheme" \
    -configuration "$configuration" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    SYMROOT="$products" \
    OBJROOT="$intermediates" \
    build > "$task_output/credential-free-$log_name-build.log" 2>&1
}

for scheme in ReluxProxyMac ReluxProxyMacTunnel; do
  build_unsigned "$scheme" Debug
  build_unsigned "$scheme" Release
done

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
provider_binary="$provider/Contents/MacOS/works.relux.tunnel.mac.tunnel"
release_provider="$products/Release/ReluxProxyMac.app/Contents/Library/SystemExtensions/works.relux.tunnel.mac.tunnel.systemextension"
release_provider_binary="$release_provider/Contents/MacOS/works.relux.tunnel.mac.tunnel"

test -d "$host"
test "$(find "$extensions" -mindepth 1 -maxdepth 1 -type d -name '*.systemextension' | wc -l | tr -d ' ')" -eq 1
test -d "$provider"
test -x "$provider_binary"
test -x "$release_provider_binary"
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

host_entitlements=Configuration/Entitlements/ReluxProxyMac-Development.entitlements
provider_entitlements=Configuration/Entitlements/ReluxProxyMacTunnel-Development.entitlements
developer_id_host_entitlements=Configuration/Entitlements/ReluxProxyMac-DeveloperID.entitlements
developer_id_provider_entitlements=Configuration/Entitlements/ReluxProxyMacTunnel-DeveloperID.entitlements

for entitlements in \
  "$host_entitlements" "$provider_entitlements" \
  "$developer_id_host_entitlements" "$developer_id_provider_entitlements"; do
  plutil -lint "$entitlements" >/dev/null
done

test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.networking.networkextension:0' "$host_entitlements")" = \
  'packet-tunnel-provider'
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.networking.networkextension:0' "$provider_entitlements")" = \
  'packet-tunnel-provider'
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.networking.networkextension:0' "$developer_id_host_entitlements")" = \
  'packet-tunnel-provider-systemextension'
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.networking.networkextension:0' "$developer_id_provider_entitlements")" = \
  'packet-tunnel-provider-systemextension'
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.system-extension.install' "$host_entitlements")" = true
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.system-extension.install' "$developer_id_host_entitlements")" = true
for entitlements in "$provider_entitlements" "$developer_id_provider_entitlements"; do
  if /usr/libexec/PlistBuddy -c 'Print :com.apple.developer.system-extension.install' "$entitlements" >/dev/null 2>&1; then
    echo "error: provider entitlement file must not install system extensions: $entitlements" >&2
    exit 1
  fi
done

for scheme in ReluxProxyMac ReluxProxyMacTunnel; do
  xcodebuild \
    -workspace ReluxTunnel.xcworkspace \
    -scheme "$scheme" \
    -configuration Debug \
    -showBuildSettings > "$task_output/$scheme-build-settings.log"
done
grep -F 'CODE_SIGN_ENTITLEMENTS = Configuration/Entitlements/ReluxProxyMac-Development.entitlements' \
  "$task_output/ReluxProxyMac-build-settings.log" >/dev/null
grep -F 'CODE_SIGN_ENTITLEMENTS = Configuration/Entitlements/ReluxProxyMacTunnel-Development.entitlements' \
  "$task_output/ReluxProxyMacTunnel-build-settings.log" >/dev/null

provider_architectures=$(lipo -archs "$release_provider_binary" | tr ' ' '\n' | LC_ALL=C sort | tr '\n' ' ')
test "$provider_architectures" = 'arm64 x86_64 '
otool -L "$release_provider_binary" > "$task_output/provider-release-linkage.log"
awk '/^[[:space:]]+\// { print $1 }' "$task_output/provider-release-linkage.log" |
  while IFS= read -r dependency; do
    case "$dependency" in
      /usr/lib/*|/System/Library/Frameworks/*) ;;
      *)
        echo "error: disallowed provider dynamic dependency: $dependency" >&2
        exit 1
        ;;
    esac
  done
nm -u "$release_provider_binary" > "$task_output/provider-release-undefined-symbols.log"
nm "$release_provider_binary" > "$task_output/provider-release-symbols.log"
./scripts/check-generated-provider-graph.py \
  --project Project.swift \
  --package Package.swift \
  --relay-root .build/relay/apple-bundle-input \
  --generated-project ReluxTunnelApp.xcodeproj/project.pbxproj \
  --provider-bundle "$release_provider" \
  --linked-libraries "$task_output/provider-release-linkage.log" \
  --undefined-symbols "$task_output/provider-release-undefined-symbols.log" \
  --all-symbols "$task_output/provider-release-symbols.log"

echo "macOS host/provider target validation passed"
