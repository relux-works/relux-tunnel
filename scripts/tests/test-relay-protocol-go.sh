#!/bin/sh
# Compile and test the generated Go relay-protocol binding in the authoritative
# relay module. Network-free: the module has no requirements and uses the pinned
# Go 1.26.5 standard library only.
set -eu

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$repo_root"

package_dir=relay/internal/protocol

host_os=$(uname -s | tr '[:upper:]' '[:lower:]')
host_arch=$(uname -m | sed -e 's/^x86_64$/amd64/' -e 's/^aarch64$/arm64/')
go_install=${RELAY_GO_INSTALL:-"$repo_root/.build/relay/toolchains/go1.26.5-$host_os-$host_arch"}
go_root=${RELAY_GOROOT:-"$go_install/go"}
go_command=${RELAY_GO:-"$go_root/bin/go"}
gofmt_command="$go_root/bin/gofmt"

if [ ! -x "$go_command" ] || [ ! -x "$gofmt_command" ]; then
    echo "checksum-provisioned Go 1.26.5 toolchain not found; run make relay-provision-go" >&2
    exit 1
fi

case $(GOROOT="$go_root" GOTOOLCHAIN=local GOENV=off "$go_command" version) in
    "go version go1.26.5 $host_os/$host_arch") ;;
    *)
        echo "required Go toolchain is go1.26.5 for $host_os/$host_arch" >&2
        exit 1
        ;;
esac

unformatted=$("$gofmt_command" -l "$package_dir")
if [ -n "$unformatted" ]; then
    echo "gofmt-non-canonical Go sources:" >&2
    echo "$unformatted" >&2
    exit 1
fi

cd relay
RELUX_TUNNEL_REPO_ROOT="$repo_root" GOROOT="$go_root" GOTOOLCHAIN=local GOENV=off GOCACHE="$repo_root/.temp/relay-go-cache" GOPATH="$repo_root/.temp/relay-go-path" GOFLAGS=-mod=readonly CGO_ENABLED=0 "$go_command" vet ./internal/protocol
RELUX_TUNNEL_REPO_ROOT="$repo_root" GOROOT="$go_root" GOTOOLCHAIN=local GOENV=off GOCACHE="$repo_root/.temp/relay-go-cache" GOPATH="$repo_root/.temp/relay-go-path" GOFLAGS=-mod=readonly CGO_ENABLED=0 "$go_command" test "$@" ./internal/protocol
echo "relay-protocol Go smoke OK"
