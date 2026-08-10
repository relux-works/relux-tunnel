#!/bin/sh
set -eu

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

forbidden='NetworkExtension|SwiftUI|UIKit|AppKit'
if grep -R -n -E "^[[:space:]]*import[[:space:]]+($forbidden)([[:space:]]|$)" Sources/ReluxTunnelCore; then
    echo "ReluxTunnelCore imports a platform-only or UI framework" >&2
    exit 1
fi

ssh_candidate_names='ReluxNIOSSH|SwiftNIO|NIOSSH|libssh2|OpenSSL'
if grep -R -n -E "$ssh_candidate_names" Sources/ReluxTunnelCore; then
    echo "ReluxTunnelCore names an SSH candidate or candidate dependency" >&2
    exit 1
fi

if grep -R -n -E "^[[:space:]]*import[[:space:]]+($forbidden)([[:space:]]|$)" \
    Sources/ReluxTunnelHarness Sources/ReluxTunnelHarnessSupport; then
    echo "ReluxTunnelHarness imports a provider-only or UI framework" >&2
    exit 1
fi

network_extension_imports=$(
    grep -R -l -E '^[[:space:]]*import[[:space:]]+NetworkExtension([[:space:]]|$)' Sources || true
)
for source in $network_extension_imports; do
    case "$source" in
        Sources/ReluxTunnelIOSAdapter/*|Sources/ReluxTunnelMacOSAdapter/*) ;;
        *)
            echo "NetworkExtension import outside named adapter modules: $source" >&2
            exit 1
            ;;
    esac
done

swift package dump-package | python3 -c '
import json, sys

package = json.load(sys.stdin)
targets = {target["name"]: target for target in package["targets"]}
required = {
    "CReluxNativeFixture",
    "HevSocks5Tunnel",
    "ReluxLibSSH2",
    "ReluxTunnelCore",
    "ReluxTunnelLibSSH2Adapter",
    "ReluxTunnelNativeAdapter",
    "ReluxTunnelIOSAdapter",
    "ReluxTunnelMacOSAdapter",
    "ReluxTunnelHarnessSupport",
    "ReluxTunnelHarness",
    "ReluxTunnelCoreTests",
    "ReluxTunnelHarnessTests",
    "ReluxTunnelNativeAdapterTests",
}
missing = required - targets.keys()
if missing:
    raise SystemExit(f"missing package targets: {sorted(missing)}")
if targets["ReluxTunnelCore"]["dependencies"]:
    raise SystemExit("ReluxTunnelCore must not depend on adapter or app targets")

def dependency_names(target):
    names = set()
    for dependency in target["dependencies"]:
        for value in dependency.values():
            if isinstance(value, list) and value:
                names.add(value[0])
            elif isinstance(value, str):
                names.add(value)
    return names

if dependency_names(targets["ReluxTunnelNativeAdapter"]) != {
    "CReluxNativeFixture",
    "HevSocks5Tunnel",
    "ReluxTunnelCore",
}:
    raise SystemExit("ReluxTunnelNativeAdapter must own the native/core boundary")
if dependency_names(targets["ReluxTunnelLibSSH2Adapter"]) != {
    "ReluxLibSSH2",
    "ReluxTunnelCore",
}:
    raise SystemExit("ReluxTunnelLibSSH2Adapter must own the libssh2/core boundary")
if dependency_names(targets["ReluxTunnelIOSAdapter"]) != {
    "ReluxTunnelCore",
    "ReluxTunnelNativeAdapter",
}:
    raise SystemExit("ReluxTunnelIOSAdapter must remain independent of the deferred iOS SSH graph")
if dependency_names(targets["ReluxTunnelMacOSAdapter"]) != {
        "ReluxTunnelCore",
        "ReluxTunnelLibSSH2Adapter",
        "ReluxTunnelNativeAdapter",
}:
    raise SystemExit("ReluxTunnelMacOSAdapter must include the named libssh2 adapter")
if dependency_names(targets["ReluxTunnelHarnessSupport"]) != {
    "ReluxTunnelCore",
    "ReluxTunnelLibSSH2Adapter",
    "ReluxTunnelNativeAdapter",
}:
    raise SystemExit("ReluxTunnelHarnessSupport must include the named libssh2 adapter")
if dependency_names(targets["ReluxTunnelHarness"]) != {
    "ReluxTunnelCore",
    "ReluxTunnelHarnessSupport",
}:
    raise SystemExit("ReluxTunnelHarness must link ReluxTunnelCore and its support target")
'

echo "ReluxTunnelCore dependency and import boundaries are valid"
