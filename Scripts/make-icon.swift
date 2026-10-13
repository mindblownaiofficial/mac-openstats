// Renders the OpenStats app icon as a PNG at the requested size.
// Usage: swift make-icon.swift <output.png> <size>
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let size = Int(args[2]) else {
    FileHandle.standardError.write("usage: make-icon.swift <output.png> <size>\n".data(using: .utf8)!)
    exit(1)
}

let s = CGFloat(size)
let image = NSImage(size: NSSize(width: s, height: s))
image.lockFocus()

// Rounded background with a deep blue gradient (macOS icon grid: ~10% inset).
let inset = s * 0.1
let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
let background = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.22, yRadius: rect.width * 0.22)
NSGradient(colors: [NSColor(calibratedRed: 0.13, green: 0.17, blue: 0.30, alpha: 1),
                    NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.14, alpha: 1)])!
    .draw(in: background, angle: -90)

// Four bars like a tiny menu-bar graph.
let barColors = [NSColor.systemBlue, NSColor.systemGreen, NSColor.systemOrange, NSColor.systemPurple]
let heights: [CGFloat] = [0.35, 0.6, 0.45, 0.8]
let barAreaWidth = rect.width * 0.62
let gap = barAreaWidth * 0.08
let barWidth = (barAreaWidth - gap * 3) / 4
let baseY = rect.minY + rect.height * 0.2
let maxHeight = rect.height * 0.6
for i in 0..<4 {
    let x = rect.midX - barAreaWidth / 2 + CGFloat(i) * (barWidth + gap)
    let barRect = NSRect(x: x, y: baseY, width: barWidth, height: maxHeight * heights[i])
    barColors[i].setFill()
    NSBezierPath(roundedRect: barRect, xRadius: barWidth * 0.25, yRadius: barWidth * 0.25).fill()
}

// A thin line graph across the top of the bars.
let line = NSBezierPath()
line.lineWidth = s * 0.02
line.lineCapStyle = .round
line.lineJoinStyle = .round
let points: [(CGFloat, CGFloat)] = [(0.2, 0.55), (0.35, 0.7), (0.5, 0.62), (0.65, 0.85), (0.8, 0.75)]
for (i, p) in points.enumerated() {
    let point = NSPoint(x: rect.minX + rect.width * p.0, y: rect.minY + rect.height * p.1)
    if i == 0 { line.move(to: point) } else { line.line(to: point) }
}
NSColor.white.withAlphaComponent(0.9).setStroke()
line.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    exit(2)
}
try! png.write(to: URL(fileURLWithPath: args[1]))
