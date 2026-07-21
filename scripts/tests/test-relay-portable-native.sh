#!/bin/sh
# Prove one portable Linux relay binary executes as the native unprivileged CI user.
set -eu

portable_root=${1:?portable output root is required}
relay_version=${2:?relay version is required}
source_commit=${3:?source commit is required}

if [ "$(uname -s)" != Linux ]; then
    echo "portable native Linux smoke requires a Linux host" >&2
    exit 1
fi
if [ "$(id -u)" -eq 0 ]; then
    echo "portable native Linux smoke must run as an unprivileged user" >&2
    exit 1
fi

case "$(uname -m)" in
    x86_64|amd64)
        architecture=amd64
        ;;
    aarch64|arm64)
        architecture=arm64
        ;;
    *)
        echo "portable native Linux smoke host architecture is unsupported" >&2
        exit 1
        ;;
esac

target="linux/$architecture"
binary="$portable_root/linux-$architecture/relux-relay-linux-$architecture"
if [ ! -x "$binary" ]; then
    echo "portable native Linux smoke binary is missing: $target" >&2
    exit 1
fi

output=$(env -i PATH=/usr/bin:/bin LC_ALL=C LANG=C TZ=UTC "$binary" smoke)
python3 -c '
import json, sys
expected = {
    "schemaVersion": 1,
    "executable": "relux-relay",
    "executableVersion": sys.argv[2],
    "protocolVersion": 1,
    "sourceRevision": sys.argv[3],
    "buildTarget": sys.argv[1],
    "contract": "metadata-and-empty-health",
    "relayBehaviorImplemented": False,
    "status": "ok",
}
if json.loads(sys.argv[4]) != expected:
    raise SystemExit("portable native Linux smoke contract mismatch")
' "$target" "$relay_version" "$source_commit" "$output"

echo "runtime $target: native unprivileged Ubuntu 24.04 fixture pass"
