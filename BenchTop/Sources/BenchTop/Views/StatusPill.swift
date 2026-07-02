import SwiftUI

extension JobStatus {
    var tint: Color {
        switch self {
        case .running: return Theme.Palette.signal
        case .done: return Theme.Palette.statusDone
        case .failed: return Theme.Palette.statusFailed
        case .queued, .unknown: return Theme.Palette.statusIdle
        }
    }

    var label: String {
        switch self {
        case .running: return "Running"
        case .done: return "Done"
        case .failed: return "Failed"
        case .queued: return "Queued"
        case .unknown: return "—"
        }
    }

    /// SF Symbol paired with the colour, so state never reads by colour alone.
    var symbol: String {
        switch self {
        case .running: return "play.fill"
        case .done: return "checkmark"
        case .failed: return "xmark"
        case .queued: return "pause"
        case .unknown: return "questionmark"
        }
    }
}

extension AlertSeverity {
    var tint: Color {
        switch self {
        case .good: return Theme.Palette.statusDone
        case .warning: return Theme.Palette.statusWarning
        case .critical: return Theme.Palette.statusFailed
        case .unknown: return Theme.Palette.statusIdle
        }
    }

    var symbol: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        case .unknown: return "bell"
        }
    }
}

/// A colour-tinted, icon+label status chip — the accessible state marker used
/// on rig cards and job rows.
struct StatusPill: View {
    var status: JobStatus
    var text: String?

    var body: some View {
        Pill(tint: status.tint, symbol: status.symbol, text: text ?? status.label)
    }
}

/// Shared pill body so alerts and connection status can reuse the look.
struct Pill: View {
    var tint: Color
    var symbol: String
    var text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold))
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tint.opacity(0.15), in: Capsule())
    }
}

#Preview {
    HStack {
        StatusPill(status: .running)
        StatusPill(status: .done)
        StatusPill(status: .failed)
        StatusPill(status: .queued)
    }
    .padding()
    .background(Theme.Palette.ink)
}
