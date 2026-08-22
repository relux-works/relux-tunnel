import ReluxAppleUITestShared
import SwiftUI

@main
struct ReluxUITestFixtureHostApp: App {
  private let launchResult: Result<ReluxUITest.LaunchConfiguration, Error>

  init() {
    launchResult = Result {
      try ReluxUITest.LaunchConfiguration.parse(
        arguments: ProcessInfo.processInfo.arguments,
        environment: ProcessInfo.processInfo.environment
      )
    }
  }

  var body: some Scene {
    WindowGroup {
      FixtureHostRootView(launchResult: launchResult)
    }
  }
}

private struct FixtureHostRootView: View {
  let launchResult: Result<ReluxUITest.LaunchConfiguration, Error>

  var body: some View {
    Group {
      switch launchResult {
      case .success(let configuration):
        FixtureStateView(configuration: configuration)
      case .failure:
        InvalidFixtureView()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

private struct FixtureStateView: View {
  let configuration: ReluxUITest.LaunchConfiguration
  @State private var isConfirmed = false

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "checkmark.shield.fill")
        .font(.largeTitle)
        .foregroundStyle(.green)
        .accessibilityHidden(true)
      Text("Deterministic UI Fixture")
        .font(.title)
        .accessibilityIdentifier(ReluxUITest.Identifier.FixtureHost.page)
      Text(configuration.fixture.displayName)
        .font(.title2)
        .accessibilityIdentifier(ReluxUITest.Identifier.FixtureHost.fixtureName)
      Text(configuration.fixture.category.rawValue.capitalized)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier(ReluxUITest.Identifier.FixtureHost.fixtureCategory)
      Text("Network and VPN APIs unavailable")
        .font(.callout)
        .accessibilityIdentifier(ReluxUITest.Identifier.FixtureHost.safetyBoundary)
      Button("Confirm fixture") {
        isConfirmed = true
      }
      .accessibilityIdentifier(ReluxUITest.Identifier.FixtureHost.confirmButton)
      Text(isConfirmed ? "Fixture confirmed" : "Fixture awaiting confirmation")
        .accessibilityIdentifier(ReluxUITest.Identifier.FixtureHost.confirmation)
    }
    .multilineTextAlignment(.center)
  }
}

private struct InvalidFixtureView: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.shield.fill")
        .font(.largeTitle)
        .foregroundStyle(.red)
        .accessibilityHidden(true)
      Text("Fixture launch rejected")
        .font(.title2)
      Text("A typed fixture and the non-networked safety boundary are required.")
        .multilineTextAlignment(.center)
    }
  }
}
