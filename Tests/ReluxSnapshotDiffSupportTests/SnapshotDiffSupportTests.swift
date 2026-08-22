import AppKit
import Foundation
import ReluxSnapshotDiffSupport
import Testing

@Suite("Snapshot failure artifacts")
struct SnapshotDiffSupportTests {
  @Test("mismatch writes reference failed and visual diff images")
  func mismatchArtifacts() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("relux-snapshot-diff-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let reference = root.appendingPathComponent("expected.png")
    let failed = root.appendingPathComponent("actual.png")
    try png(color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)).write(to: reference)
    try png(color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1)).write(to: failed)

    let output = root.appendingPathComponent("artifacts")
    #expect(
      try !SnapshotDiff.compare(reference: reference, failed: failed, outputDirectory: output))
    for name in ["reference.png", "failed.png", "diff.png"] {
      #expect(FileManager.default.fileExists(atPath: output.appendingPathComponent(name).path))
    }
  }

  private func png(color: NSColor) throws -> Data {
    let image = NSImage(size: NSSize(width: 2, height: 2))
    image.lockFocus()
    color.setFill()
    NSRect(x: 0, y: 0, width: 2, height: 2).fill()
    image.unlockFocus()
    guard
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let data = bitmap.representation(using: .png, properties: [:])
    else {
      throw SnapshotDiffError.cannotEncodePNG
    }
    return data
  }
}
