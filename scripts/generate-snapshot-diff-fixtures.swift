#!/usr/bin/swift
import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write(
    Data("usage: generate-snapshot-diff-fixtures.swift OUTPUT_DIRECTORY\n".utf8))
  exit(2)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func write(_ color: NSColor, to url: URL) throws {
  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: 32,
      pixelsHigh: 32,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    )
  else {
    throw CocoaError(.fileWriteUnknown)
  }
  for y in 0..<bitmap.pixelsHigh {
    for x in 0..<bitmap.pixelsWide {
      bitmap.setColor(color, atX: x, y: y)
    }
  }
  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    throw CocoaError(.fileWriteUnknown)
  }
  try data.write(to: url, options: .atomic)
}

try write(
  NSColor(deviceRed: 0.10, green: 0.35, blue: 0.90, alpha: 1),
  to: output.appendingPathComponent("reference-input.png")
)
try write(
  NSColor(deviceRed: 0.95, green: 0.35, blue: 0.10, alpha: 1),
  to: output.appendingPathComponent("failed-input.png")
)
