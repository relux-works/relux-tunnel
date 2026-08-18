import Foundation

enum TargetContractSupport {
  static let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

  static func data(at relativePath: String) throws -> Data {
    try Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
  }

  static func text(at relativePath: String) throws -> String {
    try String(decoding: data(at: relativePath), as: UTF8.self)
  }

  static func plist(at relativePath: String) throws -> [String: Any] {
    let object = try PropertyListSerialization.propertyList(
      from: data(at: relativePath),
      options: [],
      format: nil
    )
    return object as? [String: Any] ?? [:]
  }

  static func stringArray(_ dictionary: [String: Any], key: String) -> [String] {
    dictionary[key] as? [String] ?? []
  }

  static func xcconfig(at relativePath: String) throws -> [String: String] {
    try text(at: relativePath).split(separator: "\n").reduce(into: [:]) { values, line in
      let parts = line.split(separator: "=", maxSplits: 1).map {
        $0.trimmingCharacters(in: .whitespaces)
      }
      guard parts.count == 2, !parts[0].hasPrefix("//") else { return }
      values[parts[0]] = parts[1]
    }
  }
}
