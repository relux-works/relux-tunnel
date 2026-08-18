#!/bin/bash
set -u

repo_root="$(cd "$(dirname "$0")/.." && pwd -P)"
legacy_root="$repo_root/../relux-proxy"
task_output="$repo_root/.temp/TASK-260715-sbrrp7/credential-free-validation"
logs="$task_output/logs"
summary="$task_output/summary.log"
metadata="$task_output/environment.log"
expected_legacy_commit=2557aba1c030d0643d76e0bc3b185f6d5fd172e1

usage() {
  cat <<'USAGE'
Usage: scripts/validate-credential-free.sh [--legacy-root PATH]

Runs every credential-free generated-project foundation check. The legacy root
must be a Git checkout containing signed tag v0.1.0.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --legacy-root)
      [ "$#" -ge 2 ] || { echo "error: --legacy-root requires a path" >&2; exit 2; }
      legacy_root=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$logs"
: > "$summary"
cd "$repo_root" || exit

legacy_work_root=$(mktemp -d "${TMPDIR:-/tmp}/relux-credential-free-legacy.XXXXXX")
legacy_fixture="$legacy_work_root/legacy-v0.1.0"
cleanup() {
  case "$legacy_work_root" in
    "${TMPDIR:-/tmp}"/relux-credential-free-legacy.*)
      chmod -R u+w "$legacy_work_root" 2>/dev/null || true
      rm -rf "$legacy_work_root"
      ;;
    *)
      echo "warning: refusing to clean unexpected legacy work path: $legacy_work_root" >&2
      ;;
  esac
}
trap cleanup EXIT INT TERM

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command is unavailable: $1" >&2
    exit 2
  fi
}

for command in curl git make mise plutil python3 shasum swift xcodebuild xcrun; do
  require_command "$command"
done
if [ "$(uname -s)" != Darwin ]; then
  echo "error: credential-free generated-project validation requires macOS" >&2
  exit 2
fi
if [ ! -d "$legacy_root/.git" ]; then
  echo "error: expected a legacy Git checkout at $legacy_root" >&2
  echo "Clone relux-works/relux-proxy with tags, or pass --legacy-root PATH." >&2
  exit 2
fi

run_step() {
  name=$1
  shift
  log="$logs/$name.log"
  printf 'RUN: %s\n' "$name" | tee -a "$summary"
  if "$@" >"$log" 2>&1; then
    printf 'PASS: %s (log: %s)\n' "$name" "${log#"$repo_root"/}" | tee -a "$summary"
  else
    status=$?
    printf 'FAIL: %s (exit %s; log: %s)\n' \
      "$name" "$status" "${log#"$repo_root"/}" | tee -a "$summary" >&2
    tail -n 80 "$log" >&2
    exit "$status"
  fi
}

source_revision=$(git rev-parse HEAD)
source_date_epoch=$(git show -s --format=%ct HEAD)
marketing_version=$(sed -n 's/^MARKETING_VERSION = //p' Configuration/Versions.xcconfig)
if [ -n "$(git status --porcelain=v1 --untracked-files=normal -- . ':!.task-board' ':!.temp')" ]; then
  source_worktree_state=dirty
else
  source_worktree_state=clean
fi

run_step relay-tool-bootstrap ./scripts/bootstrap-relay-tools.sh

relay_go="$repo_root/.build/relay/toolchains/go1.26.5-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed -e 's/^x86_64$/amd64/' -e 's/^aarch64$/arm64/')/go/bin/go"
relay_syft="$repo_root/.build/relay/toolchains/syft1.48.0-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed -e 's/^x86_64$/amd64/' -e 's/^aarch64$/arm64/')/syft"

{
  echo "source_revision=$source_revision"
  echo "source_date_epoch=$source_date_epoch"
  echo "source_worktree_state=$source_worktree_state"
  echo "host=$(sw_vers -productName) $(sw_vers -productVersion) ($(uname -m))"
  echo "xcode=$(xcodebuild -version | tr '\n' ';' | sed 's/;$//')"
  echo "swift=$(swift --version 2>&1 | head -n 1)"
  echo "mise=$(mise --version | head -n 1)"
  echo "tuist=$(mise exec -- tuist version | head -n 1)"
  echo "go=$($relay_go version)"
  echo "syft=$($relay_syft version | sed -n 's/^Version:[[:space:]]*//p')"
  echo "macos_deployment_target=$(sed -n 's/^MACOSX_DEPLOYMENT_TARGET = //p' Configuration/Base.xcconfig)"
  echo "ios_deployment_target=$(sed -n 's/^IPHONEOS_DEPLOYMENT_TARGET = //p' Configuration/Base.xcconfig)"
  echo "invoked_schemes=ReluxProxyMac(Debug,Release,test),ReluxProxyMacTunnel(Debug,Release)"
  echo "sdk_inventory_begin"
  xcodebuild -showsdks
  echo "sdk_inventory_end"
} > "$metadata"

run_step validation-contract-tests ./scripts/tests/test-credential-free-validation.sh
run_step deterministic-generation ./scripts/validate-workspace-foundation.sh
run_step macos-target-builds-and-contracts ./scripts/validate-macos-targets.sh
run_step core-boundaries ./scripts/check-core-boundaries.sh
run_step swift-testing swift test
run_step swift-release-build swift build -c release
run_step native-packaging make check-native-dependencies test-native-dependencies

run_step relay-shell-smoke env \
  RELAY_VERSION="$marketing_version" \
  SOURCE_COMMIT="$source_revision" \
  SOURCE_DATE_EPOCH="$source_date_epoch" \
  make relay-shell-validate

run_step legacy-clone git clone --quiet --local --no-hardlinks "$legacy_root" "$legacy_fixture"
run_step legacy-checkout git -C "$legacy_fixture" checkout --quiet "$expected_legacy_commit"
run_step legacy-preservation ./scripts/check-legacy-preservation.sh \
  --legacy-root "$legacy_fixture" --workspace-root "$repo_root"
run_step legacy-guard-tests ./scripts/tests/test-legacy-preservation-guard.sh \
  --legacy-root "$legacy_fixture"
run_step legacy-swift-test swift test --package-path "$legacy_fixture"
run_step legacy-swift-release-build swift build -c release --package-path "$legacy_fixture"

{
  echo "NOT RUN: production signing, physical Gate P0, Developer ID archive, notarization, and DMG publication require credentials or belong to downstream release gates."
  echo "NOT RUN: ReluxProxyIOS and ReluxProxyIOSTunnel are deferred by ADR-024/ADR-027 and must remain absent from the macOS-only graph."
  echo "PASS: credential-free generated-project validation"
  echo "metadata: ${metadata#"$repo_root"/}"
  echo "logs: ${logs#"$repo_root"/}"
} | tee -a "$summary"
