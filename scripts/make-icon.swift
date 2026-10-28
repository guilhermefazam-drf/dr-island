// Generates Resources/AppIcon.icns: a Doutor Finanças blue macOS tile with the notch island and a gauge.
// Usage: swift scripts/make-icon.swift   (run once; bundle.sh copies the result into the app)
import AppKit

func draw(size s: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s), pixelsHigh: Int(s), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let rect = CGRect(x: 0, y: 0, width: s, height: s).insetBy(dx: s * 0.05, dy: s * 0.05)   // room for the macOS shadow margin

    // Tile in the Doutor Finanças blue (#00A6E5, lighter at the top, darker at the bottom).
    let tile = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.2237, yRadius: rect.width * 0.2237)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill(); tile.fill()
    ctx.restoreGState()
    tile.addClip()
    NSGradient(colors: [NSColor(red: 0x4D/255, green: 0xC3/255, blue: 0xF0/255, alpha: 1),
                        NSColor(red: 0x00/255, green: 0xA6/255, blue: 0xE5/255, alpha: 1),
                        NSColor(red: 0x00/255, green: 0x86/255, blue: 0xBA/255, alpha: 1)])!.draw(in: rect, angle: -90)

    // Gauge: a 240° arc, white where it is "filled" and translucent after, with a needle.
    let center = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.38)
    let radius = rect.width * 0.28
    let start = 210.0, end = -30.0   // degrees, clockwise through the top
    let fill = 0.62                  // how much of the arc is lit
    func arc(from t0: Double, to t1: Double, color: NSColor) {
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: start + (end - start) * t0, endAngle: start + (end - start) * t1, clockwise: true)
        path.lineWidth = rect.width * 0.07
        path.lineCapStyle = .round
        color.setStroke(); path.stroke()
    }
    arc(from: 0, to: 1, color: NSColor.white.withAlphaComponent(0.28))
    arc(from: 0, to: fill, color: .white)
    let angle = (start + (end - start) * fill) * .pi / 180
    let needle = NSBezierPath()
    needle.move(to: center)
    needle.line(to: CGPoint(x: center.x + cos(angle) * radius * 0.78, y: center.y + sin(angle) * radius * 0.78))
    needle.lineWidth = rect.width * 0.04
    needle.lineCapStyle = .round
    NSColor.white.setStroke(); needle.stroke()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - rect.width * 0.04, y: center.y - rect.width * 0.04, width: rect.width * 0.08, height: rect.width * 0.08)).fill()

    // The island: a black pill hanging from the top edge with a thin white ring.
    let pill = CGRect(x: rect.midX - rect.width * 0.28, y: rect.maxY - rect.height * 0.215, width: rect.width * 0.56, height: rect.height * 0.19)
    let island = NSBezierPath(roundedRect: pill, xRadius: pill.height * 0.5, yRadius: pill.height * 0.5)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.03, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    NSColor.black.setFill(); island.fill()
    ctx.restoreGState()
    NSColor.white.withAlphaComponent(0.9).setStroke()
    island.lineWidth = rect.width * 0.012
    island.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let fm = FileManager.default
let iconset = "Resources/AppIcon.iconset"
try? fm.removeItem(atPath: iconset)
try fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)
let sizes: [(String, CGFloat)] = [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                                  ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)]
for (name, size) in sizes {
    let data = draw(size: size).representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: "\(iconset)/icon_\(name).png"))
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset, "-o", "Resources/AppIcon.icns"]
try task.run(); task.waitUntilExit()
try? fm.removeItem(atPath: iconset)
print(task.terminationStatus == 0 ? "Resources/AppIcon.icns" : "iconutil failed")
