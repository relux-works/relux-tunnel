import Darwin
import Foundation

public enum HarnessResourceError: Error, Equatable {
  case unixSocketPathTooLong
  case unixSocketCreationFailed(Int32)
  case unixSocketBindFailed(Int32)
}

public actor HarnessResourceScope {
  public typealias CleanupOperation = @Sendable () async -> Void

  private var cleanupOperations: [CleanupOperation] = []
  private var hasCleanedUp = false

  public init() {}

  public func registerCleanup(_ operation: @escaping CleanupOperation) {
    guard !hasCleanedUp else {
      return
    }
    cleanupOperations.append(operation)
  }

  public func makeTemporaryDirectory(prefix: String) throws -> URL {
    let filteredPrefix = prefix.filter { $0.isLetter || $0.isNumber || $0 == "-" }
    let safePrefix = String(filteredPrefix.prefix(12))
    // Keep the lexical path below sockaddr_un.sun_path's macOS limit. The
    // per-user temporary directory under /var/folders can already be too long.
    let directory = URL(fileURLWithPath: "/tmp", isDirectory: true)
      .appendingPathComponent("\(safePrefix)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    registerCleanup {
      try? FileManager.default.removeItem(at: directory)
    }
    return directory
  }

  @discardableResult
  public func bindUnixDatagramSocket(at path: URL) throws -> Int32 {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)

    let pathBytes = Array(path.path.utf8CString)
    let pathCapacity = MemoryLayout.size(ofValue: address.sun_path)
    guard pathBytes.count <= pathCapacity else {
      throw HarnessResourceError.unixSocketPathTooLong
    }

    _ = withUnsafeMutablePointer(to: &address.sun_path.0) { destination in
      pathBytes.withUnsafeBytes { source in
        memcpy(destination, source.baseAddress, source.count)
      }
    }

    let descriptor = Darwin.socket(AF_UNIX, SOCK_DGRAM, 0)
    guard descriptor >= 0 else {
      throw HarnessResourceError.unixSocketCreationFailed(errno)
    }

    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    let result = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
        Darwin.bind(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    guard result == 0 else {
      let bindError = errno
      Darwin.close(descriptor)
      throw HarnessResourceError.unixSocketBindFailed(bindError)
    }

    registerCleanup {
      _ = Darwin.close(descriptor)
      _ = path.path.withCString { Darwin.unlink($0) }
    }
    return descriptor
  }

  @discardableResult
  public func startTask(
    operation: @escaping @Sendable () async -> Void
  ) -> Task<Void, Never> {
    let task = Task(operation: operation)
    registerCleanup {
      task.cancel()
      await task.value
    }
    return task
  }

  public func cleanup() async {
    guard !hasCleanedUp else {
      return
    }
    hasCleanedUp = true
    let operations = cleanupOperations.reversed()
    cleanupOperations.removeAll()
    for operation in operations {
      await operation()
    }
  }
}
