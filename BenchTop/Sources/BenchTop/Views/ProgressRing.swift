import SwiftUI

/// A circular percent-done ring with a label in the center, used on the
/// GPU tiles, current-focus card, and job rows.
struct ProgressRing: View {
    var fraction: Double?
    var lineWidth: CGFloat = 8
    var tint: Color = Theme.Palette.signal
    /// Shown centered instead of the percentage (e.g. "✓" for completed).
    var glyph: String?

    private var clamped: Double {
        min(max(fraction ?? 0, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: fraction == nil ? 1 : clamped)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(fraction == nil ? 0.3 : 1)
                .animation(.easeInOut, value: clamped)

            if let glyph {
                Text(glyph)
                    .font(.btData(15, weight: .bold))
                    .foregroundStyle(tint)
            } else if let fraction {
                Text(fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.btData(14, weight: .bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
            } else {
                Text("—")
                    .font(.btData(14))
                    .foregroundStyle(Theme.Palette.textTertiary)
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
