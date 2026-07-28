#!/bin/zsh
# TASK-260728-7ii1xz — keychain context reachability experiment.
# Privacy-safe: only the fixed literal PROBE-NOT-A-SECRET is written/read.
set -u
D=/Users/iv/Developer/relux-tunnel/.temp/TASK-260728-7ii1xz
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$D/known_hosts -o ConnectTimeout=5 localhost"

run() { echo "\n\$ $*"; eval "$@"; echo "exit=$?"; }

echo "=== TASK-260728-7ii1xz keychain reachability experiment"
run "sw_vers -productVersion; sw_vers -buildVersion"
run "id -un; id -u"

echo "\n### E0 baseline: is this shell a GUI login session?"
run "launchctl managername"
run "$SSH 'launchctl managername'"
run "$SSH 'id -u; echo non-gui-session-uid-above'"

echo "\n### E1 data-protection keychain, GUI user session, uid 502"
run "$D/kcprobe add e1-gui"
run "$D/kcprobe read e1-gui"

echo "\n### E2 data-protection keychain, NON-GUI session (ssh localhost), same uid 502"
run "$SSH '$D/kcprobe add e2-nongui'"
run "$SSH '$D/kcprobe read e2-nongui'"
run "$SSH '$D/kcprobe read e1-gui'"

echo "\n### E3 file-based keychain, GUI user session (default = login keychain)"
run "$D/kcprobe add e3-gui --file"
run "$D/kcprobe read e3-gui --file"

echo "\n### E4 file-based keychain, NON-GUI session (ssh localhost)"
run "$SSH '$D/kcprobe add e4-nongui --file'"
run "$SSH '$D/kcprobe read e3-gui --file'"

echo "\n### E5 System keychain (file-based, root-owned) as the logged-in user"
run "ls -l /Library/Keychains/System.keychain"
run "security add-generic-password -s works.relux.tunnel.probe.7ii1xz -a e5-sys -w PROBE-NOT-A-SECRET /Library/Keychains/System.keychain"
run "security find-generic-password -s works.relux.tunnel.probe.7ii1xz /Library/Keychains/System.keychain"
run "security dump-keychain /Library/Keychains/System.keychain > /dev/null"

echo "\n### E6 per-user data-protection keychain storage is per-\$HOME"
run "ls -d ~/Library/Keychains/*/keychain-2.db"
run "ls -ld /private/var/root"
run "ls -ld '/private/var/root/Library/Group Containers'"

echo "\n### cleanup"
run "$D/kcprobe delete e1-gui"
run "$SSH '$D/kcprobe delete e2-nongui'"
run "$D/kcprobe delete e3-gui --file"
run "$SSH '$D/kcprobe delete e4-nongui --file'"
echo "\n=== end"
