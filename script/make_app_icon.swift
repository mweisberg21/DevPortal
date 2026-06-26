import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let sizes: [(name: String, pixels: Int)] = [
  ("icon_16x16.png", 16),
  ("icon_16x16@2x.png", 32),
  ("icon_32x32.png", 32),
  ("icon_32x32@2x.png", 64),
  ("icon_128x128.png", 128),
  ("icon_128x128@2x.png", 256),
  ("icon_256x256.png", 256),
  ("icon_256x256@2x.png", 512),
  ("icon_512x512.png", 512),
  ("icon_512x512@2x.png", 1024)
]

func drawIcon(size: Int) throws -> NSBitmapImageRep {
  guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  ) else {
    throw NSError(domain: "DevPortalIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create \(size)x\(size) bitmap"])
  }

  bitmap.size = NSSize(width: size, height: size)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  defer { NSGraphicsContext.restoreGraphicsState() }

  let rect = NSRect(x: 0, y: 0, width: size, height: size)
  NSGraphicsContext.current?.imageInterpolation = .high
  NSGraphicsContext.current?.shouldAntialias = true

  let background = NSGradient(colors: [
    NSColor(red: 0.04, green: 0.12, blue: 0.16, alpha: 1),
    NSColor(red: 0.03, green: 0.32, blue: 0.34, alpha: 1),
    NSColor(red: 0.06, green: 0.58, blue: 0.48, alpha: 1)
  ])
  let radius = CGFloat(size) * 0.22
  let backgroundPath = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.055, dy: CGFloat(size) * 0.055), xRadius: radius, yRadius: radius)
  background?.draw(in: backgroundPath, angle: 38)

  NSColor.white.withAlphaComponent(0.16).setStroke()
  backgroundPath.lineWidth = max(1, CGFloat(size) * 0.018)
  backgroundPath.stroke()

  let terminalRect = NSRect(
    x: CGFloat(size) * 0.18,
    y: CGFloat(size) * 0.29,
    width: CGFloat(size) * 0.64,
    height: CGFloat(size) * 0.42
  )
  let terminalPath = NSBezierPath(roundedRect: terminalRect, xRadius: CGFloat(size) * 0.055, yRadius: CGFloat(size) * 0.055)
  NSColor(red: 0.02, green: 0.035, blue: 0.045, alpha: 0.88).setFill()
  terminalPath.fill()

  NSColor.white.withAlphaComponent(0.20).setStroke()
  terminalPath.lineWidth = max(1, CGFloat(size) * 0.012)
  terminalPath.stroke()

  let titleBar = NSRect(
    x: terminalRect.minX,
    y: terminalRect.maxY - CGFloat(size) * 0.09,
    width: terminalRect.width,
    height: CGFloat(size) * 0.09
  )
  NSColor.white.withAlphaComponent(0.10).setFill()
  NSBezierPath(roundedRect: titleBar, xRadius: CGFloat(size) * 0.04, yRadius: CGFloat(size) * 0.04).fill()

  let dotRadius = max(1.5, CGFloat(size) * 0.014)
  for index in 0..<3 {
    let x = terminalRect.minX + CGFloat(size) * 0.052 + CGFloat(index) * CGFloat(size) * 0.043
    let y = terminalRect.maxY - CGFloat(size) * 0.055
    let dot = NSBezierPath(ovalIn: NSRect(x: x, y: y, width: dotRadius * 2, height: dotRadius * 2))
    [NSColor.systemRed, NSColor.systemYellow, NSColor.systemGreen][index].withAlphaComponent(0.95).setFill()
    dot.fill()
  }

  NSColor(red: 0.52, green: 1.0, blue: 0.78, alpha: 1).setStroke()
  let prompt = NSBezierPath()
  prompt.lineWidth = max(2, CGFloat(size) * 0.035)
  prompt.lineCapStyle = .round
  prompt.lineJoinStyle = .round
  prompt.move(to: NSPoint(x: terminalRect.minX + CGFloat(size) * 0.12, y: terminalRect.minY + CGFloat(size) * 0.18))
  prompt.line(to: NSPoint(x: terminalRect.minX + CGFloat(size) * 0.20, y: terminalRect.midY))
  prompt.line(to: NSPoint(x: terminalRect.minX + CGFloat(size) * 0.12, y: terminalRect.maxY - CGFloat(size) * 0.20))
  prompt.stroke()

  let cursor = NSBezierPath()
  cursor.lineWidth = max(2, CGFloat(size) * 0.033)
  cursor.lineCapStyle = .round
  cursor.move(to: NSPoint(x: terminalRect.minX + CGFloat(size) * 0.29, y: terminalRect.minY + CGFloat(size) * 0.18))
  cursor.line(to: NSPoint(x: terminalRect.minX + CGFloat(size) * 0.45, y: terminalRect.minY + CGFloat(size) * 0.18))
  cursor.stroke()

  NSColor.white.withAlphaComponent(0.92).setFill()
  let badgeRect = NSRect(
    x: CGFloat(size) * 0.62,
    y: CGFloat(size) * 0.14,
    width: CGFloat(size) * 0.24,
    height: CGFloat(size) * 0.24
  )
  NSBezierPath(ovalIn: badgeRect).fill()

  NSColor(red: 0.02, green: 0.34, blue: 0.32, alpha: 1).setStroke()
  let badge = NSBezierPath()
  badge.lineWidth = max(2, CGFloat(size) * 0.026)
  badge.lineCapStyle = .round
  let center = NSPoint(x: badgeRect.midX, y: badgeRect.midY)
  let nodeDistance = CGFloat(size) * 0.055
  let nodes = [
    NSPoint(x: center.x, y: center.y + nodeDistance),
    NSPoint(x: center.x - nodeDistance, y: center.y - nodeDistance * 0.55),
    NSPoint(x: center.x + nodeDistance, y: center.y - nodeDistance * 0.55)
  ]
  badge.move(to: nodes[0])
  badge.line(to: nodes[1])
  badge.move(to: nodes[0])
  badge.line(to: nodes[2])
  badge.move(to: nodes[1])
  badge.line(to: nodes[2])
  badge.stroke()

  NSColor(red: 0.02, green: 0.34, blue: 0.32, alpha: 1).setFill()
  for node in nodes {
    NSBezierPath(ovalIn: NSRect(
      x: node.x - CGFloat(size) * 0.018,
      y: node.y - CGFloat(size) * 0.018,
      width: CGFloat(size) * 0.036,
      height: CGFloat(size) * 0.036
    )).fill()
  }

  return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
  guard let png = bitmap.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "DevPortalIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render \(url.lastPathComponent)"])
  }

  try png.write(to: url)
}

for size in sizes {
  try writePNG(try drawIcon(size: size.pixels), to: iconsetURL.appendingPathComponent(size.name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
  throw NSError(domain: "DevPortalIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

print("Wrote \(icnsURL.path)")
