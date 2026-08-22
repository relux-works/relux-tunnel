import AppKit
import ReluxAppleUITestShared

_ = ReluxProxyBuildIdentity.providerProtocolVersion
_ = ReluxUITest.Identifier.FixtureHost.page

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
application.run()
