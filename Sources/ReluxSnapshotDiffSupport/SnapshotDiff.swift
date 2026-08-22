import AppKit
import Foundation

public enum SnapshotDiffError: Error {
  case unreadableImage(URL)
  case incompatibleDimensions
  case cannotCreateBitmap
  case cannotEncodePNG
}

public enum SnapshotDiff {
  /// Writes a review packet and returns `true` when every pixel matches.
  public static func compare(
    reference referenceURL: URL,
    failed failedURL: URL,
    outputDirectory: URL
  ) throws -> Bool {
    guard
      let referenceData = try? Data(contentsOf: referenceURL),
      let reference = NSBitmapImageRep(data: referenceData)
    else {
      throw SnapshotDiffError.unreadableImage(referenceURL)
    }
    guard
      let failedData = try? Data(contentsOf: failedURL),
      let failed = NSBitmapImageRep(data: failedData)
    else {
      throw SnapshotDiffError.unreadableImage(failedURL)
    }
    guard reference.pixelsWide == failed.pixelsWide, reference.pixelsHigh == failed.pixelsHigh
    else {
      throw SnapshotDiffError.incompatibleDimensions
    }
    guard
      let diff = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: reference.pixelsWide,
        pixelsHigh: reference.pixelsHigh,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
      )
    else {
      throw SnapshotDiffError.cannotCreateBitmap
    }

    var matches = true
    for y in 0..<reference.pixelsHigh {
      for x in 0..<reference.pixelsWide {
        let expected = reference.colorAt(x: x, y: y) ?? .clear
        let actual = failed.colorAt(x: x, y: y) ?? .clear
        let equal =
          expected.usingColorSpace(NSColorSpace.deviceRGB)
          == actual.usingColorSpace(NSColorSpace.deviceRGB)
        matches = matches && equal
        diff.setColor(equal ? dimmed(expected) : highlighted(actual), atX: x, y: y)
      }
    }

    try FileManager.default.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    try FileManager.default.copyReplacingItem(
      at: referenceURL,
      to: outputDirectory.appendingPathComponent("reference.png")
    )
    try FileManager.default.copyReplacingItem(
      at: failedURL,
      to: outputDirectory.appendingPathComponent("failed.png")
    )
    guard
      let data = diff.representation(using: NSBitmapImageRep.FileType.png, properties: [:])
    else {
      throw SnapshotDiffError.cannotEncodePNG
    }
    try data.write(
      to: outputDirectory.appendingPathComponent("diff.png"),
      options: Data.WritingOptions.atomic
    )
    return matches
  }

  private static func dimmed(_ color: NSColor) -> NSColor {
    let rgb = color.usingColorSpace(.deviceRGB) ?? .clear
    let luminance = (rgb.redComponent + rgb.greenComponent + rgb.blueComponent) / 3
    return NSColor(deviceWhite: luminance * 0.35, alpha: 0.65)
  }

  private static func highlighted(_ color: NSColor) -> NSColor {
    let rgb = color.usingColorSpace(.deviceRGB) ?? .clear
    return NSColor(
      deviceRed: min(1, rgb.redComponent + 0.65),
      green: rgb.greenComponent * 0.2,
      blue: rgb.blueComponent * 0.2,
      alpha: 1
    )
  }
}

extension FileManager {
  fileprivate func copyReplacingItem(at source: URL, to destination: URL) throws {
    if fileExists(atPath: destination.path) {
      try removeItem(at: destination)
    }
    try copyItem(at: source, to: destination)
  }
}
