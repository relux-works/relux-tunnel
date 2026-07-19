import Foundation

public enum InternalSOCKSUDPMode: Sendable {
  /// The fixed HEV UDP-in-TCP component contract from ADR-004.
  case udpInTCP
}

/// Caller-owned HEV/lwIP limits. Values are measured in later packet-plane work.
public struct InternalSOCKSConfiguration: Equatable, Sendable {
  public let taskStackSizeBytes: Int
  public let tcpBufferSizeBytes: Int
  public let maximumSessionCount: Int
  public let udpMode: InternalSOCKSUDPMode

  public init(
    taskStackSizeBytes: Int,
    tcpBufferSizeBytes: Int,
    maximumSessionCount: Int,
    udpMode: InternalSOCKSUDPMode = .udpInTCP
  ) {
    self.taskStackSizeBytes = taskStackSizeBytes
    self.tcpBufferSizeBytes = tcpBufferSizeBytes
    self.maximumSessionCount = maximumSessionCount
    self.udpMode = udpMode
  }
}

/// Upstream boundary consumed by the process-local internal SOCKS component.
public protocol InternalSOCKSUpstream: AnyObject, Sendable {
  func openTCP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> any SSHByteChannel
  func sendUDPFrame(_ frame: Data) async throws
}

/// The internal SOCKS endpoint is a component seam, not a user proxy API.
public protocol InternalSOCKSComponent: AnyObject, Sendable {
  func start(
    configuration: InternalSOCKSConfiguration,
    upstream: any InternalSOCKSUpstream
  ) async throws
  func stop() async
}
