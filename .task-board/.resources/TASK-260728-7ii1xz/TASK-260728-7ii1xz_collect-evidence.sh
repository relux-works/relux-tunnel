#!/bin/zsh
# TASK-260728-7ii1xz — consolidated physical evidence collection on this Mac.
# Privacy-safe: reads only public code-signing metadata, file modes, and the
# system sandbox profile. No secret value is read, written, or printed.
set -u
run() { echo "\n\$ $*"; eval "$@"; echo "exit=$?"; }

echo "=== TASK-260728-7ii1xz physical evidence (host)"
run "sw_vers"
run "uname -m"

echo "\n### P1 — a macOS NE system extension runs as root"
run "systemextensionsctl list | sed -n '1,8p'"
run "ps -axo user,uid,pid,comm | grep 'network-extension' | grep -v grep"

echo "\n### P2 — shipping NE sysex entitlements (public code-signing metadata)"
for b in /Library/SystemExtensions/*/*.systemextension; do
  echo "\n\$ codesign -d --entitlements :- --xml '$b' | plutil -convert json -o - -"
  codesign -d --entitlements :- --xml "$b" 2>/dev/null | plutil -convert json -o - - 2>/dev/null | python3 -m json.tool
  echo "exit=$?"
done

echo "\n### P3 — App Sandbox grants /Library/Keychains to any NE-entitled process"
run "shasum -a 256 /System/Library/Sandbox/Profiles/application.sb"
run "grep -n -A1 'when (entitlement \"com.apple.developer.networking.networkextension\")' /System/Library/Sandbox/Profiles/application.sb | tail -4"
run "grep -n 'com.apple.SecurityServer\|com.apple.securityd.xpc' /System/Library/Sandbox/Profiles/application.sb"
run "sed -n '543,546p' /System/Library/Sandbox/Profiles/application.sb"

echo "\n### P4 — keychain file layout and unlock key"
run "ls -l /Library/Keychains/System.keychain /private/var/db/SystemKey"
run "ls -d \$HOME/Library/Keychains/*/keychain-2.db"
run "ls -ld /private/var/root"
run "ls -ld '/private/var/root/Library/Group Containers'"
echo "\n=== end"
