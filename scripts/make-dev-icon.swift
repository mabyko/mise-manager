// Derives the Debug app icon from the release master: same glyph, plus a red "DEV" badge top-right.
// Usage: swift scripts/make-dev-icon.swift <master.png> <out.png>
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let master = NSImage(contentsOfFile: args[1]) else {
    fputs("usage: make-dev-icon.swift <master.png> <out.png>\n", stderr)
    exit(1)
}
let size = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
master.draw(in: NSRect(x: 0, y: 0, width: size, height: size))

let badge = NSRect(x: 600, y: 820, width: 340, height: 140)
NSColor(red: 0.84, green: 0.19, blue: 0.16, alpha: 1).setFill()
NSBezierPath(roundedRect: badge, xRadius: 44, yRadius: 44).fill()
let label = NSAttributedString(string: "DEV", attributes: [
    .font: NSFont.systemFont(ofSize: 104, weight: .heavy),
    .foregroundColor: NSColor.white,
])
let textSize = label.size()
label.draw(at: NSPoint(x: badge.midX - textSize.width / 2, y: badge.midY - textSize.height / 2))
NSGraphicsContext.restoreGraphicsState()

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
