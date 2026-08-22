import Foundation
import ReluxSnapshotDiffSupport

guard CommandLine.arguments.count == 4 else {
  FileHandle.standardError.write(
    Data("usage: relux-snapshot-diff REFERENCE FAILED OUTPUT_DIRECTORY\n".utf8)
  )
  exit(2)
}

do {
  let matches = try SnapshotDiff.compare(
    reference: URL(fileURLWithPath: CommandLine.arguments[1]),
    failed: URL(fileURLWithPath: CommandLine.arguments[2]),
    outputDirectory: URL(fileURLWithPath: CommandLine.arguments[3])
  )
  exit(matches ? 0 : 1)
} catch {
  FileHandle.standardError.write(Data("snapshot diff failed: \(error)\n".utf8))
  exit(2)
}
