import Foundation
import ReluxLibSSH2
import ReluxTunnelCore

class LibSSH2ByteChannel: SSHByteChannel, @unchecked Sendable {
  public let identity: SSHChannelIdentity
  let owner: LibSSH2Transport

  init(identity: SSHChannelIdentity, owner: LibSSH2Transport) {
    self.identity = identity
    self.owner = owner
  }

  public func read(maximumBytes: Int) async throws -> Data? {
    try await owner.channelRead(identity: identity, maximumBytes: maximumBytes, stream: 0)
  }

  public func writeSome(_ bytes: Data) async throws -> Int {
    try await owner.channelWrite(identity: identity, bytes: bytes)
  }

  public func finishWriting() async throws {
    try await owner.channelFinishWriting(identity: identity)
  }

  public func receiveWindow() async -> SSHDeferredSemanticReport<SSHReceiveWindowSnapshot> {
    await owner.channelDeferredWindow(identity: identity)
  }

  public func cancel() async {
    await owner.channelCancel(identity: identity)
  }

  public func reset() async {
    await owner.channelReset(identity: identity)
  }

  public func close() async {
    await owner.channelClose(identity: identity)
  }
}

final class LibSSH2ExecChannel: LibSSH2ByteChannel, SSHExecChannel, @unchecked Sendable {
  public func readStandardError(maximumBytes: Int) async throws -> Data? {
    try await owner.channelRead(
      identity: identity,
      maximumBytes: maximumBytes,
      stream: Int32(SSH_EXTENDED_DATA_STDERR)
    )
  }

  public func waitForExit() async throws -> SSHExecExit {
    try await owner.channelExit(identity: identity)
  }
}
