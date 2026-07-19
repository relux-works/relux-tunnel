import Foundation

public struct SSHProfile: Equatable, Sendable {
  public let configurationReference: TunnelConfigurationReference

  public init(configurationReference: TunnelConfigurationReference) {
    self.configurationReference = configurationReference
  }
}

public struct SSHHostKeyEvidence: Equatable, Sendable {
  public let algorithm: String
  public let keyBytes: Data
  public let fingerprint: String

  public init(algorithm: String, keyBytes: Data, fingerprint: String) {
    self.algorithm = algorithm
    self.keyBytes = keyBytes
    self.fingerprint = fingerprint
  }
}

public struct SSHSession: Equatable, Sendable {
  public let identifier: String
  public let hostKey: SSHHostKeyEvidence

  public init(identifier: String, hostKey: SSHHostKeyEvidence) {
    self.identifier = identifier
    self.hostKey = hostKey
  }
}

/// Per-channel limits supplied by the later engine decision and memory budget.
public struct SSHChannelPolicy: Equatable, Sendable {
  public let initialReceiveWindowBytes: Int
  public let maximumQueuedWriteBytes: Int

  public init(initialReceiveWindowBytes: Int, maximumQueuedWriteBytes: Int) {
    self.initialReceiveWindowBytes = initialReceiveWindowBytes
    self.maximumQueuedWriteBytes = maximumQueuedWriteBytes
  }
}

public protocol SSHByteChannel: AnyObject, Sendable {
  func read(maximumBytes: Int) async throws -> Data?
  func write(_ bytes: Data) async throws
  func finishWriting() async throws
  func close() async
}

public protocol SSHExecChannel: SSHByteChannel {
  func readStandardError(maximumBytes: Int) async throws -> Data?
}

/// Streaming input for relay upload without requiring an SFTP subsystem.
public protocol SSHUploadSource: Sendable {
  func read(maximumBytes: Int) async throws -> Data?
}

public struct SSHTransportMetrics: Equatable, Sendable {
  public let bytesSent: UInt64
  public let bytesReceived: UInt64
  public let openChannelCount: Int
  public let queuedWriteBytes: Int

  public init(
    bytesSent: UInt64,
    bytesReceived: UInt64,
    openChannelCount: Int,
    queuedWriteBytes: Int
  ) {
    self.bytesSent = bytesSent
    self.bytesReceived = bytesReceived
    self.openChannelCount = openChannelCount
    self.queuedWriteBytes = queuedWriteBytes
  }
}

/// Engine-neutral SSH surface. Engine selection remains ADR-014/TASK-260715-1gjxer.
///
/// `upload` is an exec-stdin operation, not SFTP.
public protocol SSHTransport: AnyObject, Sendable {
  func connect(profile: SSHProfile) async throws -> SSHSession
  func openDirectTCPIP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint,
    policy: SSHChannelPolicy
  ) async throws -> any SSHByteChannel
  func openExecChannel(command: String) async throws -> any SSHExecChannel
  func upload(
    source: any SSHUploadSource,
    remotePath: String,
    chunkSize: Int
  ) async throws
  func requestRekey() async throws
  func metrics() async -> SSHTransportMetrics
  func close() async
}
