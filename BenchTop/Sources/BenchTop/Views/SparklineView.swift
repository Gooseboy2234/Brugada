import SwiftUI

/// A compact line sparkline with an optional filled area and an emphasized
/// endpoint dot — the live scientific heartbeat, drawn small. Hand-rolled
/// (no Swift Charts) so it stays deterministic and tiny.
struct SparklineView: View {
    var values: [Double]
    var tint: Color = Theme.Palette.signal
    var showsArea: Bool = true
    var showsEndpoint: Bool = true

    var body: some View {
        GeometryReader { geo in
            let points = normalized(in: geo.size)
            if points.count >= 2 {
                if showsArea {
                    area(points, height: geo.size.height)
                        .fill(tint.opacity(0.14))
                }
                line(points)
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                if showsEndpoint, let last = points.last {
                    Circle().fill(tint).frame(width: 4, height: 4).position(last)
                }
            } else {
                Rectangle().fill(Theme.Palette.hairline)
                    .frame(height: 1).position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }

    private func normalized(in size: CGSize) -> [CGPoint] {
        guard values.count >= 2 else { return [] }
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let span = hi - lo
        let dx = size.width / CGFloat(values.count - 1)
        let pad: CGFloat = 2
        return values.enumerated().map { i, v in
            let t = span > 0 ? (v - lo) / span : 0.5
            let y = size.height - pad - CGFloat(t) * (size.height - 2 * pad)
            return CGPoint(x: CGFloat(i) * dx, y: y)
        }
    }

    private func line(_ pts: [CGPoint]) -> Path {
        var p = Path()
        p.addLines(pts)
        return p
    }

    private func area(_ pts: [CGPoint], height: CGFloat) -> Path {
        var p = Path()
        guard let first = pts.first, let last = pts.last else { return p }
        p.move(to: CGPoint(x: first.x, y: height))
        p.addLines(pts)
        p.addLine(to: CGPoint(x: last.x, y: height))
        p.closeSubpath()
        return p
    }
}

#Preview {
    VStack(spacing: 20) {
        SparklineView(values: [4.6, 4.9, 5.2, 5.3, 5.4], tint: Theme.Palette.statusFailed)
            .frame(width: 120, height: 34)
        SparklineView(values: [3.2, 3.1, 3.05, 3.1, 3.1], tint: Theme.Palette.statusDone)
            .frame(width: 120, height: 34)
    }
    .padding()
    .background(Theme.Palette.surface)
}
