#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
task_output="$repo_root/.temp/TASK-260715-2btjwm"
mkdir -p "$task_output"
cd "$repo_root"

package_hash_before=$(shasum -a 256 Package.swift | awk '{print $1}')
tracked_state_before=$(git status --porcelain=v1 --untracked-files=all -- . ':!.task-board' ':!.temp')

./scripts/generate-workspace.sh --clean
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

scheme_count=$(sed -n '/^[[:space:]]*Schemes:/,$p' "$task_output/xcodebuild-list.log" \
  | grep -c '^        [^ ]')
test "$scheme_count" -eq 6

for scheme in \
  ReluxProxyMac \
  ReluxProxyMacTunnel \
  ReluxTunnelCore \
  ReluxTunnelHarness \
  relux-relay \
  relux-relay-protocol-test
do
  grep -F "        $scheme" "$task_output/xcodebuild-list.log" >/dev/null
done

for deferred_scheme in ReluxProxyIOS ReluxProxyIOSTunnel; do
  if grep -F "        $deferred_scheme" "$task_output/xcodebuild-list.log" >/dev/null; then
    echo "error: deferred iOS scheme must not be generated in macOS-only mode: $deferred_scheme" >&2
    exit 1
  fi
done

grep -F 'Build configuration list for PBXProject "ReluxTunnelApp"' \
  ReluxTunnelApp.xcodeproj/project.pbxproj >/dev/null
xcodebuild -project ReluxTunnelApp.xcodeproj -list > "$task_output/xcodebuild-project-list.log"
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
