#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
manifest="$repo_root/relay/toolchain-manifest-v1.json"
download_root="$repo_root/.build/relay/downloads"

case "$(uname -s)/$(uname -m)" in
  Darwin/arm64) host=darwin/arm64 ;;
  Darwin/x86_64) host=darwin/amd64 ;;
  *)
    echo "error: credential-free Apple validation requires a supported macOS host" >&2
    exit 1
    ;;
esac

mkdir -p "$download_root"

manifest_value() {
  tool=$1
  field=$2
  python3 - "$manifest" "$host" "$tool" "$field" <<'PY'
import json
import sys

manifest_path, host, tool, field = sys.argv[1:]
with open(manifest_path, encoding="utf-8") as stream:
    manifest = json.load(stream)
if tool == "go":
    item = next(entry for entry in manifest["hostToolArchives"] if entry["host"] == host)
else:
    definition = next(entry for entry in manifest["buildOnlyTools"] if entry["name"] == tool)
    item = next(entry for entry in definition["hostArchives"] if entry["host"] == host)
print(item[field])
PY
}

provision() {
  tool=$1
  archive=$(manifest_value "$tool" artifact)
  expected_sha=$(manifest_value "$tool" sha256)
  source_url=$(manifest_value "$tool" source)
  destination="$download_root/$archive"

  if [ ! -f "$destination" ] ||
    [ "$(shasum -a 256 "$destination" | awk '{print $1}')" != "$expected_sha" ]; then
    rm -f "$destination"
    curl --fail --location --proto '=https' --tlsv1.2 \
      --output "$destination" "$source_url"
  fi
  printf '%s  %s\n' "$expected_sha" "$destination" | shasum -a 256 --check --status

  case "$tool" in
    go) make -C "$repo_root" relay-provision-go RELAY_GO_ARCHIVE="$destination" ;;
    syft) make -C "$repo_root" relay-provision-syft RELAY_SYFT_ARCHIVE="$destination" ;;
  esac
}

python3 "$repo_root/scripts/relay_release.py" toolchain-check
provision go
provision syft

echo "checksum-pinned relay tools are provisioned for $host"
