Root cause evidence from the physical macOS 26.5 run:
- neagent queried provider works.relux.tunnel.probe.mac.tunnel at extension point com.apple.networkextension.packet-tunnel and PlugInKit returned zero matches.
- pluginkit does not list the embedded provider even though LaunchServices lists both host and provider bundle IDs.
- The signed host and provider entitlements contain Network Extension but omit com.apple.security.app-sandbox.
- This exactly matches the known macOS registration failure mode where a Network Extension app extension is not indexed without App Sandbox.
- Apple documentation confirms the Info.plist extension point and embedding shape are already correct.

Focused rework:
1. Add com.apple.security.app-sandbox=true to both the host and provider entitlements, preserving the exact Network Extension entitlement and the explicit no-App-Groups/no-Keychain-Sharing scope.
2. Extend inspector and drift tests so both signed products must have App Sandbox and any forbidden sharing entitlement still fails closed.
3. Rebuild/archive/sign with the already approved exact identifiers/profiles/team; do not touch or inspect notarization credentials.
4. Install only to the exact disposable probe paths and re-run PlugInKit discovery plus the physical 10-cycle lifecycle and controlled reinstall gates.
5. If admin/UI interaction is irreducible, stop with the exact command/dialog; otherwise continue autonomously.
6. Do not expand the probe into forwarding, SSH, DNS, or production behavior.