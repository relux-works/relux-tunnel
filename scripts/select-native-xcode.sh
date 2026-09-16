#!/bin/sh
# Select the Xcode that produced the pinned native artifacts, then prove it.
#
# NativeDependencies/manifest.json pins a single Xcode build for both native
# dependencies (libssh2-openssl compiler.xcode_build and hev-lwip
# rebuild.xcode_build). Verification (scripts/libssh2-fork-tool.py verify)
# rejects any other build, so the hosted job must select the pinned Xcode
# explicitly instead of relying on the runner default. Unknown or disagreeing
# pins are refused: supporting a new toolchain is an explicit decision with
# rebuilt artifacts, never silent drift.
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
manifest=${RELUX_NATIVE_MANIFEST:-"$repo_root/NativeDependencies/manifest.json"}

pins=$(python3 - "$manifest" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        manifest = json.load(handle)
    dependencies = manifest["dependencies"]
    libssh2 = dependencies["libssh2-openssl"]["compiler"]["xcode_build"]
    hev = dependencies["hev-lwip"]["rebuild"]["xcode_build"]
except (OSError, ValueError, KeyError, TypeError) as error:
    print(f"select-native-xcode: cannot read pinned Xcode builds: {error}", file=sys.stderr)
    raise SystemExit(2)
if not libssh2 or not hev:
    print("select-native-xcode: pinned Xcode build is empty", file=sys.stderr)
    raise SystemExit(2)
if libssh2 != hev:
    print(f"select-native-xcode: refusing disagreeing pins: libssh2 {libssh2}, hev {hev}",
          file=sys.stderr)
    raise SystemExit(2)
print(libssh2)
PY
)
expected_build=$pins

# Pinned build -> installed Xcode, per the official runner inventory
# (actions/runner-images images/macos/macos-26-arm64-Readme.md). A build with
# no row here has no supported hosted Xcode and must be refused, not guessed.
# RELUX_XCODE_ROOT exists only so tests can stage a fake install tree; hosted
# runners always use the /Applications default below.
xcode_root=${RELUX_XCODE_ROOT:-/Applications}
case "$expected_build" in
  17F42) xcode_app="$xcode_root/Xcode_26.5.app" ;;
  *)
    echo "select-native-xcode: no supported hosted Xcode for pinned build $expected_build" >&2
    exit 2
    ;;
esac

if [ ! -d "$xcode_app" ]; then
  echo "select-native-xcode: expected $xcode_app is not installed" >&2
  exit 2
fi

developer_dir="$xcode_app/Contents/Developer"
current_dir=$(xcode-select -p)
if [ "$current_dir" != "$developer_dir" ]; then
  sudo xcode-select -s "$developer_dir"
fi

version_output=$(xcodebuild -version)
# Exact complete build value: the pin must equal the whole token after
# "Build version ", never a substring (17F42 must not match 17F420).
build_line=$(printf '%s\n' "$version_output" | grep '^Build version ' | tail -n 1)
actual_build=${build_line#Build version }
if [ "$actual_build" != "$expected_build" ]; then
  echo "select-native-xcode: Xcode build mismatch: expected Build version $expected_build, got $version_output" >&2
  exit 1
fi

echo "select-native-xcode: using $xcode_app (Build version $expected_build)"
