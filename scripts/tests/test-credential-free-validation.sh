#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
work_root=$(mktemp -d "${TMPDIR:-/tmp}/relux-credential-free-contract.XXXXXX")
cleanup() {
  case "$work_root" in
    "${TMPDIR:-/tmp}"/relux-credential-free-contract.*) rm -rf "$work_root" ;;
    *) echo "warning: refusing to clean unexpected test path: $work_root" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

write_list() {
  destination=$1
  shift
  {
    echo 'Information about workspace "ReluxTunnel":'
    echo '    Schemes:'
    for scheme in "$@"; do
      printf '        %s\n' "$scheme"
    done
  } > "$destination"
}

valid="$work_root/valid.log"
missing="$work_root/missing.log"
unexpected="$work_root/unexpected.log"
adversarial="$work_root/adversarial.log"

write_list "$valid" \
  relux-relay relux-relay-protocol-test ReluxProxyMac ReluxProxyMacTunnel \
  ReluxTunnelCore ReluxTunnelHarness
write_list "$missing" \
  relux-relay relux-relay-protocol-test ReluxProxyMacTunnel \
  ReluxTunnelCore ReluxTunnelHarness
write_list "$unexpected" \
  relux-relay relux-relay-protocol-test ReluxProxyMac ReluxProxyMacTunnel \
  ReluxTunnelCore ReluxTunnelHarness UnexpectedScheme
write_list "$adversarial" \
  relux-relay relux-relay-protocol-test ReluxProxyMacTunnel \
  ReluxTunnelCore ReluxTunnelHarness UnexpectedScheme

"$repo_root/scripts/check-workspace-schemes.sh" "$valid" >/dev/null
for invalid in "$missing" "$unexpected" "$adversarial"; do
  if "$repo_root/scripts/check-workspace-schemes.sh" "$invalid" >/dev/null 2>&1; then
    echo "error: invalid scheme fixture unexpectedly passed: $invalid" >&2
    exit 1
  fi
done

workflow="$repo_root/.github/workflows/ci.yml"
runner_label='    runs-on: macos-15'
mise_action='      - uses: jdx/mise-action@3c2e0cf82a5b2e5249f0d3635a4d83d0ae861518 # v4.2.5'
arm64_checksum='          sha256: c7a0eb1035de974b42d36b69c4b55b836c06b455b990dd6ac530aaf05d4a8a17 # mise-v2026.3.10-macos-arm64'
test "$(grep -Fxc "$runner_label" "$workflow")" -eq 1
test "$(grep -Fxc "$mise_action" "$workflow")" -eq 1
grep -Fx '          version: 2026.3.10' "$workflow" >/dev/null
test "$(grep -Fxc "$arm64_checksum" "$workflow")" -eq 1
grep -Fx '          install: false' "$workflow" >/dev/null
test "$(grep -Fc 'make credential-free-validate LEGACY_ROOT=' "$workflow")" -eq 1

runner_line=$(grep -nF "$runner_label" "$workflow" | cut -d: -f1)
mise_line=$(grep -nF "$mise_action" "$workflow" | cut -d: -f1)
checksum_line=$(grep -nF "$arm64_checksum" "$workflow" | cut -d: -f1)
gate_line=$(grep -nF 'make credential-free-validate LEGACY_ROOT=' "$workflow" | cut -d: -f1)
test "$runner_line" -lt "$mise_line"
test "$mise_line" -lt "$checksum_line"
test "$mise_line" -lt "$gate_line"

echo "credential-free validation contract tests passed"
