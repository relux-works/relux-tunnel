import Foundation

enum ProbeContract {
  static let identifier = "works.relux.packet-tunnel-probe"
  static let currentVersion: UInt16 = 1
  static let maximumMessageSize = 4 * 1_024
  static let configurationVersionKey = "probeProtocolVersion"
  static let startOptionKey = "probeProtocolVersion"

  static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }()
  static let decoder = JSONDecoder()
}

enum ProbeCommand: String, Codable, Equatable, Sendable {
  case getStatus
}

enum ProbeLifecycleState: String, Codable, Equatable, Sendable {
  case running
}

enum ProbeWireError: Error, Equatable {
  case oversizedMessage
  case invalidProtocolIdentifier
  case unsupportedProtocolVersion(UInt16)
  case unsupportedCommand
  case packetForwardingMustBeDisabled
}

struct ProbeRequest: Codable, Equatable, Sendable {
  let protocolIdentifier: String
  let protocolVersion: UInt16
  let command: ProbeCommand

  init() {
    protocolIdentifier = ProbeContract.identifier
    protocolVersion = ProbeContract.currentVersion
    command = .getStatus
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    protocolIdentifier = try container.decode(String.self, forKey: .protocolIdentifier)
    protocolVersion = try container.decode(UInt16.self, forKey: .protocolVersion)
    command = try container.decode(ProbeCommand.self, forKey: .command)
    guard protocolIdentifier == ProbeContract.identifier else {
      throw ProbeWireError.invalidProtocolIdentifier
    }
    guard protocolVersion == ProbeContract.currentVersion else {
      throw ProbeWireError.unsupportedProtocolVersion(protocolVersion)
    }
    guard command == .getStatus else {
      throw ProbeWireError.unsupportedCommand
    }
  }
}

struct ProbeResponse: Codable, Equatable, Sendable {
  let protocolIdentifier: String
  let protocolVersion: UInt16
  let providerBundleIdentifier: String
  let lifecycleState: ProbeLifecycleState
  let packetForwarding: Bool

  init(providerBundleIdentifier: String) {
    protocolIdentifier = ProbeContract.identifier
    protocolVersion = ProbeContract.currentVersion
    self.providerBundleIdentifier = providerBundleIdentifier
    lifecycleState = .running
    packetForwarding = false
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    protocolIdentifier = try container.decode(String.self, forKey: .protocolIdentifier)
    protocolVersion = try container.decode(UInt16.self, forKey: .protocolVersion)
    providerBundleIdentifier = try container.decode(
      String.self,
      forKey: .providerBundleIdentifier
    )
    lifecycleState = try container.decode(ProbeLifecycleState.self, forKey: .lifecycleState)
    packetForwarding = try container.decode(Bool.self, forKey: .packetForwarding)
    guard protocolIdentifier == ProbeContract.identifier else {
      throw ProbeWireError.invalidProtocolIdentifier
    }
    guard protocolVersion == ProbeContract.currentVersion else {
      throw ProbeWireError.unsupportedProtocolVersion(protocolVersion)
    }
    guard !packetForwarding else {
      throw ProbeWireError.packetForwardingMustBeDisabled
    }
  }
}

enum ProbeMessageResponder {
  static func response(to message: Data, providerBundleIdentifier: String) throws -> Data {
    guard message.count <= ProbeContract.maximumMessageSize else {
      throw ProbeWireError.oversizedMessage
    }
    _ = try ProbeContract.decoder.decode(ProbeRequest.self, from: message)
    return try ProbeContract.encoder.encode(
      ProbeResponse(providerBundleIdentifier: providerBundleIdentifier)
    )
  }
}
