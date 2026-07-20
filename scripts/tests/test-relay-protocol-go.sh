#!/bin/sh
# Compile and test the generated Go relay-protocol binding (TASK-260715-2azda7).
#
# The authoritative relay Go module scaffold belongs to TASK-260715-27uz4n and
# does not exist yet, so this smoke synthesizes a throwaway module under .temp/
# from the checked-in relay/internal/protocol sources. It proves the generated
# file is gofmt-canonical, vets clean, and passes the handwritten parity tests
# with the locally available Go toolchain. Network-free: no module requirements,
# GOTOOLCHAIN=local.
set -eu

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$repo_root"

package_dir=relay/internal/protocol
smoke_root=.temp/relay-protocol-go-smoke

command -v go >/dev/null 2>&1 || {
    echo "go toolchain not found on PATH" >&2
    exit 1
}

unformatted=$(gofmt -l "$package_dir")
if [ -n "$unformatted" ]; then
    echo "gofmt-non-canonical Go sources:" >&2
    echo "$unformatted" >&2
    exit 1
fi

rm -rf "$smoke_root"
mkdir -p "$smoke_root/protocol"
cp "$package_dir"/*.go "$smoke_root/protocol/"
cat > "$smoke_root/go.mod" <<'EOF'
module relayprotocolsmoke

go 1.25
EOF

cd "$smoke_root"
GOTOOLCHAIN=local GOFLAGS=-mod=mod CGO_ENABLED=0 go vet ./...
GOTOOLCHAIN=local GOFLAGS=-mod=mod CGO_ENABLED=0 go test ./...
echo "relay-protocol Go smoke OK"
