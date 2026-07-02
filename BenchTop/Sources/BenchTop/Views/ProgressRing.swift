import SwiftUI

/// A circular percent-done ring with a label in the center, used on the
/// GPU tiles and campaign detail screen.
struct ProgressRing: View {
    var fraction: Double?
    var lineWidth: CGFloat = 8
    var tint: Color = .accentColor

    private var clamped: Double {
        min(max(fraction ?? 0, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: fraction == nil ? 1 : clamped)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(fraction == nil ? 0.3 : 1)
                .animation(.easeInOut, value: clamped)

            VStack(spacing: 2) {
                if let fraction {
                    Text(fraction, format: .percent.precision(.fractionLength(0)))
                        .font(.headline)
                        .monospacedDigit()
                } else {
                    Text("—")
                        .font(.headline)
                }
            }
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        ProgressRing(fraction: 0.315)
        ProgressRing(fraction: nil)
    }
    .frame(height: 80)
    .padding()
}
