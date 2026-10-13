import SwiftUI

struct GraphSeries {
    var values: [Double]
    var color: Color
}

/// Scrolling line graph. New values enter from the right; the graph is full once
/// `capacity` samples have been collected.
struct LineGraph: View {
    var series: [GraphSeries]
    var capacity: Int
    var maxValue: Double? = nil
    var lineWidth: CGFloat = 1.5
    var filled = true

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let peak = maxValue ?? max(series.flatMap(\.values).max() ?? 1, 1e-9)
            ZStack {
                ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                    let points = Self.points(s.values, size: size, peak: peak, capacity: capacity)
                    if filled, points.count > 1 {
                        Self.area(points, height: size.height).fill(s.color.opacity(0.22))
                    }
                    Self.line(points).stroke(s.color, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                }
            }
        }
        .clipped()
    }

    static func points(_ values: [Double], size: CGSize, peak: Double, capacity: Int) -> [CGPoint] {
        let n = values.count
        guard n > 0 else { return [] }
        let denominator = Double(max(capacity - 1, 1))
        return values.enumerated().map { i, v in
            let x = size.width * Double(capacity - n + i) / denominator
            let y = size.height - size.height * min(max(v / peak, 0), 1)
            return CGPoint(x: x, y: y)
        }
    }

    static func line(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for p in points.dropFirst() { path.addLine(to: p) }
        return path
    }

    static func area(_ points: [CGPoint], height: CGFloat) -> Path {
        var path = line(points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: height))
        path.addLine(to: CGPoint(x: first.x, y: height))
        path.closeSubpath()
        return path
    }
}

/// Horizontal usage bar, optionally stacked from several segments.
struct UsageBar: View {
    var segments: [(fraction: Double, color: Color)]
    var height: CGFloat = 8

    init(fraction: Double, color: Color, height: CGFloat = 8) {
        segments = [(fraction, color)]
        self.height = height
    }

    init(segments: [(fraction: Double, color: Color)], height: CGFloat = 8) {
        self.segments = segments
        self.height = height
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    Rectangle()
                        .fill(seg.color)
                        .frame(width: max(0, geo.size.width * min(max(seg.fraction, 0), 1)))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: height)
        .background(Color.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: height / 2))
    }
}
