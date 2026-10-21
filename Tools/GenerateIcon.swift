// Writes the app icon as an Icon Composer bundle (Resources/AppIcon.icon),
// which scripts/make-icon.sh compiles with actool into the Assets.car and
// AppIcon.icns that build.sh copies into the app.
//
// Same format as Squiggle's Tools/GenerateIcon.swift: an Icon Composer icon
// (not a flat .icns with its own tile — macOS 26+ shrinks those onto a grey
// tile), Squiggle's navy gradient fill and mint glyph, neutral shadow and
// 0.3 translucency, so the two apps read as siblings. The system draws the
// shape, glass lighting, and dark/tinted variants itself.
//
// The glyph is Lucide's `train-front` (lucide 1.54.0), transcribed from its
// SVG path data on Lucide's 24-unit grid and stroked at Lucide's width of 2.
//
// Usage: swift Tools/GenerateIcon.swift <AppIcon.icon>

import AppKit
import Foundation

private enum Icon {
    static let canvas = 1024
    /// The glyph's 24-unit grid as a fraction of the canvas. train-front
    /// spans 4…20 × 3…22 on that grid, so a square box this size gives it
    /// about the same visual weight as Squiggle's chart symbol.
    static let glyphFraction: CGFloat = 0.62

    static let fillTop = "srgb:0.10600,0.18400,0.29000,1.00000"
    static let fillBottom = "srgb:0.03500,0.05500,0.09800,1.00000"
    static let stroke = NSColor(srgbRed: 0.549, green: 0.867, blue: 0.678, alpha: 1)
}

/// lucide/icons/train-front.svg, in Lucide's y-down 24-unit space.
///   M8 3.1V7a4 4 0 0 0 8 0V3.1
///   m9 15-1-1
///   m15 15 1-1
///   M9 19c-2.8 0-5-2.2-5-5v-4a8 8 0 0 1 16 0v4c0 2.8-2.2 5-5 5Z
///   m8 19-2 3
///   m16 19 2 3
/// The context is flipped, so angles increase clockwise on screen and
/// `clockwise: false` means "increasing angle".
private func trainFront() -> NSBezierPath {
    let p = NSBezierPath()
    // Windscreen: down the left side, a half-circle (r4, centre 12,7) under
    // the bottom — 180° → 0° passing 90° (down) — and back up the right side.
    p.move(to: NSPoint(x: 8, y: 3.1))
    p.line(to: NSPoint(x: 8, y: 7))
    p.appendArc(withCenter: NSPoint(x: 12, y: 7), radius: 4,
                startAngle: 180, endAngle: 0, clockwise: true)
    p.line(to: NSPoint(x: 16, y: 3.1))
    // Headlights.
    p.move(to: NSPoint(x: 9, y: 15)); p.line(to: NSPoint(x: 8, y: 14))
    p.move(to: NSPoint(x: 15, y: 15)); p.line(to: NSPoint(x: 16, y: 14))
    // Body: rounded bottom corners (cubics) and a domed top (r8, centre 12,10,
    // 180° → 360° passing 270° = up).
    p.move(to: NSPoint(x: 9, y: 19))
    p.curve(to: NSPoint(x: 4, y: 14),
            controlPoint1: NSPoint(x: 6.2, y: 19), controlPoint2: NSPoint(x: 4, y: 16.8))
    p.line(to: NSPoint(x: 4, y: 10))
    p.appendArc(withCenter: NSPoint(x: 12, y: 10), radius: 8,
                startAngle: 180, endAngle: 360, clockwise: false)
    p.line(to: NSPoint(x: 20, y: 14))
    p.curve(to: NSPoint(x: 15, y: 19),
            controlPoint1: NSPoint(x: 20, y: 16.8), controlPoint2: NSPoint(x: 17.8, y: 19))
    p.close()
    // Rails.
    p.move(to: NSPoint(x: 8, y: 19)); p.line(to: NSPoint(x: 6, y: 22))
    p.move(to: NSPoint(x: 16, y: 19)); p.line(to: NSPoint(x: 18, y: 22))
    return p
}

/// The glyph alone, on a transparent canvas, as the bundle's one layer.
private func renderGlyph() -> NSBitmapImageRep? {
    let side = CGFloat(Icon.canvas)
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Icon.canvas, pixelsHigh: Icon.canvas,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: rep)
    else { return nil }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    context.shouldAntialias = true
    let cg = context.cgContext

    // Flip to Lucide's y-down space and scale its 24-unit grid into a centred
    // box. The glyph's own extent (4…20 × 3…22) is centred, not the grid.
    let box = side * Icon.glyphFraction
    let scale = box / 24
    let glyphCentre = NSPoint(x: 12, y: 12.5)
    cg.translateBy(x: 0, y: side)
    cg.scaleBy(x: 1, y: -1)
    cg.translateBy(x: side / 2, y: side / 2)
    cg.scaleBy(x: scale, y: scale)
    cg.translateBy(x: -glyphCentre.x, y: -glyphCentre.y)

    let path = trainFront()
    path.lineWidth = 2            // Lucide's stroke width, in grid units
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    Icon.stroke.setStroke()
    path.stroke()
    return rep
}

private let manifest = """
{
  "fill" : {
    "linear-gradient" : [
      "\(Icon.fillTop)",
      "\(Icon.fillBottom)"
    ]
  },
  "groups" : [
    {
      "layers" : [ { "image-name" : "glyph.png", "name" : "glyph" } ],
      "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
      "translucency" : { "enabled" : true, "value" : 0.3 }
    }
  ],
  "supported-platforms" : { "squares" : [ "macOS" ] }
}

"""

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: GenerateIcon <AppIcon.icon>\n".utf8))
    exit(2)
}

let bundle = URL(fileURLWithPath: arguments[1])
let assets = bundle.appendingPathComponent("Assets")
try? FileManager.default.removeItem(at: bundle)
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

guard let rep = renderGlyph(), let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to render the glyph\n".utf8))
    exit(1)
}
try png.write(to: assets.appendingPathComponent("glyph.png"))
try Data(manifest.utf8).write(to: bundle.appendingPathComponent("icon.json"))

print("Wrote \(bundle.path)")
