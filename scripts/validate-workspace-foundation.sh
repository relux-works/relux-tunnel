#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
task_output="$repo_root/.temp/TASK-260715-2btjwm"
mkdir -p "$task_output"
cd "$repo_root"

package_hash_before=$(shasum -a 256 Package.swift | awk '{print $1}')
tracked_state_before=$(git status --porcelain=v1 --untracked-files=all -- . ':!.task-board' ':!.temp')

./scripts/generate-workspace.sh --clean
./scripts/check-generated-provider-graph.py \
  --project Project.swift \
  --package Package.swift \
  --relay-root .build/relay/relay-assets-v1 \
  --generated-project ReluxTunnelApp.xcodeproj/project.pbxproj
find ReluxTunnel.xcworkspace ReluxTunnelApp.xcodeproj -type f \
  ! -path '*/xcuserdata/*' -print0 \
  | LC_ALL=C sort -z \
  | xargs -0 shasum -a 256 > "$task_output/generation-01.sha256"

./scripts/generate-workspace.sh --clean
find ReluxTunnel.xcworkspace ReluxTunnelApp.xcodeproj -type f \
  ! -path '*/xcuserdata/*' -print0 \
  | LC_ALL=C sort -z \
  | xargs -0 shasum -a 256 > "$task_output/generation-02.sha256"

diff -u "$task_output/generation-01.sha256" "$task_output/generation-02.sha256"

package_hash_after=$(shasum -a 256 Package.swift | awk '{print $1}')
test "$package_hash_before" = "$package_hash_after"

tracked_state_after=$(git status --porcelain=v1 --untracked-files=all -- . ':!.task-board' ':!.temp')
test "$tracked_state_before" = "$tracked_state_after"

xcodebuild -workspace ReluxTunnel.xcworkspace -list > "$task_output/xcodebuild-list.log"
./scripts/check-workspace-schemes.sh "$task_output/xcodebuild-list.log"

grep -F 'Build configuration list for PBXProject "ReluxTunnelApp"' \
  ReluxTunnelApp.xcodeproj/project.pbxproj >/dev/null
xcodebuild -project ReluxTunnelApp.xcodeproj -list > "$task_output/xcodebuild-project-list.log"
target_count=$(sed -n '/^[[:space:]]*Targets:/,/Build Configurations:/p' \
  "$task_output/xcodebuild-project-list.log" | grep -c '^        [^ ]')
test "$target_count" -eq 8
for target in \
  ReluxProxyMac ReluxProxyMacTunnel ReluxProxyMacTests ReluxProxyMacTunnelTests \
  ReluxProxyMacUITestFixtureHost ReluxProxyMacUITests \
  ReluxProxyIOSUITestFixtureHost ReluxProxyIOSUITests; do
  grep -Fx "        $target" "$task_output/xcodebuild-project-list.log" >/dev/null
done
for deferred_target in ReluxProxyIOS ReluxProxyIOSTunnel ReluxProxyIOSTests ReluxProxyIOSTunnelTests; do
  if grep -Fx "        $deferred_target" "$task_output/xcodebuild-project-list.log" >/dev/null; then
    echo "error: deferred iOS target must not be generated in macOS-only mode: $deferred_target" >&2
    exit 1
  fi
done
configuration_count=$(sed -n '/^[[:space:]]*Build Configurations:/,/If no build configuration/p' \
  "$task_output/xcodebuild-project-list.log" | grep -c '^        [^ ]')
test "$configuration_count" -eq 2
grep -Fx '        Debug' "$task_output/xcodebuild-project-list.log" >/dev/null
grep -Fx '        Release' "$task_output/xcodebuild-project-list.log" >/dev/null
grep -F 'XCLocalSwiftPackageReference "."' \
  ReluxTunnelApp.xcodeproj/project.pbxproj >/dev/null
if grep -F 'Signing.local.xcconfig' ReluxTunnelApp.xcodeproj/project.pbxproj >/dev/null; then
  echo "error: generated project must not reference the ignored signing overlay" >&2
  exit 1
fi

grep -Fx 'MACOSX_DEPLOYMENT_TARGET = 15.0' Configuration/Base.xcconfig >/dev/null
grep -Fx 'IPHONEOS_DEPLOYMENT_TARGET = 18.0' Configuration/Base.xcconfig >/dev/null
grep -Fx 'SWIFT_VERSION = 6.0' Configuration/Base.xcconfig >/dev/null
grep -Fx 'SWIFT_STRICT_CONCURRENCY = complete' Configuration/Base.xcconfig >/dev/null
grep -Fx 'CODE_SIGNING_ALLOWED = NO' Configuration/Base.xcconfig >/dev/null
grep -Fx 'CODE_SIGNING_REQUIRED = NO' Configuration/Base.xcconfig >/dev/null
grep -Fx 'APPLICATION_EXTENSION_API_ONLY = YES' \
  Configuration/Provider-Debug.xcconfig >/dev/null
grep -Fx 'APPLICATION_EXTENSION_API_ONLY = YES' \
  Configuration/Provider-Release.xcconfig >/dev/null
grep -Ex 'MARKETING_VERSION = [0-9]+\.[0-9]+\.[0-9]+' \
  Configuration/Versions.xcconfig >/dev/null
grep -Ex 'CURRENT_PROJECT_VERSION = [1-9][0-9]*' \
  Configuration/Versions.xcconfig >/dev/null

git check-ignore -q ReluxTunnel.xcworkspace
git check-ignore -q ReluxTunnelApp.xcodeproj
git check-ignore -q Configuration/Signing.local.xcconfig

echo "workspace foundation validation passed"
