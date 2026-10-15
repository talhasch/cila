// Renders Resources/AppIcon.icns. Run: swift scripts/make-icon.swift [preview.png]
import AppKit

let canvas: CGFloat = 1024

/// Four-pointed sparkle centred at `c` with outer radius `r`.
func sparkle(_ c: CGPoint, _ r: CGFloat, pinch: CGFloat = 0.16) -> NSBezierPath {
    let path = NSBezierPath()
    let tips = [CGPoint(x: c.x, y: c.y + r), CGPoint(x: c.x + r, y: c.y),
                CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x - r, y: c.y)]
    let k = r * pinch
    path.move(to: tips[0])
    for i in 0..<4 {
        let next = tips[(i + 1) % 4]
        // Control point pulled towards the centre gives the concave sides.
        let mid = CGPoint(x: (tips[i].x + next.x) / 2, y: (tips[i].y + next.y) / 2)
        let control = CGPoint(x: c.x + (mid.x - c.x) * pinch * 2 + (mid.x > c.x ? k : -k) * 0.2,
                              y: c.y + (mid.y - c.y) * pinch * 2 + (mid.y > c.y ? k : -k) * 0.2)
        path.curve(to: next, controlPoint1: control, controlPoint2: control)
    }
    path.close()
    return path
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)

    // macOS icon grid: 824pt rounded square inset 100pt, with a soft drop shadow.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill()
    shape.fill()
    ctx.restoreGState()

    ctx.saveGState()
    shape.addClip()
    NSGradient(colors: [
        NSColor(red: 0.98, green: 0.45, blue: 0.75, alpha: 1),  // pink (top right)
        NSColor(red: 0.55, green: 0.33, blue: 0.96, alpha: 1),  // violet
        NSColor(red: 0.20, green: 0.24, blue: 0.80, alpha: 1),  // indigo (bottom left)
    ])!.draw(in: tile, angle: -125)

    // Glossy sheen across the top half: the "polish".
    NSGradient(colorsAndLocations:
        (NSColor.white.withAlphaComponent(0.24), 0),
        (NSColor.white.withAlphaComponent(0.06), 0.45),
        (NSColor.white.withAlphaComponent(0), 0.7))!
        .draw(in: tile, angle: -90)

    // Sparkles with a soft glow.
    ctx.setShadow(offset: .zero, blur: 40, color: NSColor.white.withAlphaComponent(0.7).cgColor)
    NSColor.white.setFill()
    sparkle(CGPoint(x: 470, y: 470), 270).fill()
    NSColor.white.withAlphaComponent(0.95).setFill()
    sparkle(CGPoint(x: 735, y: 720), 115).fill()
    NSColor.white.withAlphaComponent(0.85).setFill()
    sparkle(CGPoint(x: 735, y: 300), 62).fill()
    ctx.restoreGState()

    // Hairline edge highlight.
    NSColor.white.withAlphaComponent(0.18).setStroke()
    let edge = NSBezierPath(roundedRect: tile.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183)
    edge.lineWidth = 4
    edge.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appending(path: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try! render(size: base).write(to: iconset.appending(path: "icon_\(base)x\(base).png"))
    try! render(size: base * 2).write(to: iconset.appending(path: "icon_\(base)x\(base)@2x.png"))
}

let output = root.appending(path: "Resources/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try! iconutil.run()
iconutil.waitUntilExit()
if let preview = CommandLine.arguments.dropFirst().first {
    try! render(size: 1024).write(to: URL(fileURLWithPath: preview))
}
print("Wrote \(output.path)")
