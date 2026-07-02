import SwiftUI

/// The whole cure journey as one pipeline — the screen you'd screenshot to
/// explain the project. Its whole reason for existing is the SIMULATION WALL:
/// a hard, always-drawn line between what a GPU can tell you (above) and what
/// only a wet lab can (below). The app never lets the funnel *look* like a GPU
/// can finish the cure. Percentages are of the computational journey — never
/// "% to cure". Tap any stage for its honest caveat.
struct FunnelView: View {
    @EnvironmentObject private var store: BenchTopStore
    @State private var expanded: Int?

    /// The furthest-along campaign is the canonical view of the journey.
    private var campaign: Campaign? {
        store.campaigns.max { lhs, rhs in
            (lhs.percentComplete ?? 0) < (rhs.percentComplete ?? 0)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let campaign {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text(campaign.title.replacingOccurrences(of: " · MD replicates", with: ""))
                            .font(.btTitle).foregroundStyle(Theme.Palette.textPrimary)
                        Text("Computational journey — not “% to cure”.")
                            .font(.btCaption).foregroundStyle(Theme.Palette.textSecondary)
                            .padding(.bottom, Theme.Space.s)

                        ForEach(campaign.funnel) { stage in
                            if stage.isWall {
                                WallDivider(caveat: stage.caveat)
                            } else {
                                StageRow(stage: stage, expanded: expanded == stage.index) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expanded = expanded == stage.index ? nil : stage.index
                                    }
                                }
                            }
                        }
                    }
                    .padding(Theme.Space.l)
                } else {
                    ContentUnavailableView("No journey yet", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .padding(.top, 80)
                }
            }
            .background(Theme.Palette.ink)
            .navigationTitle("Funnel")
            #if os(iOS)
            .toolbarBackground(Theme.Palette.ink, for: .navigationBar)
            #endif
            .refreshable { await store.refresh() }
        }
    }
}

private struct StageRow: View {
    var stage: Stage
    var expanded: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: Theme.Space.m) {
                    marker
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stage.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(stage.status == .upcoming ? Theme.Palette.textSecondary : Theme.Palette.textPrimary)
                        if let detail = stage.detail {
                            Text(detail).font(.btCaption).foregroundStyle(Theme.Palette.textTertiary)
                        }
                    }
                    Spacer()
                    if stage.caveat != nil {
                        Image(systemName: expanded ? "chevron.up" : "info.circle")
                            .font(.system(size: 12)).foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                if expanded, let caveat = stage.caveat {
                    Text(caveat)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 30)
                }
            }
            .padding(Theme.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var marker: some View {
        ZStack {
            Circle().fill(color.opacity(0.18)).frame(width: 22, height: 22)
            Image(systemName: symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(color)
        }
    }

    private var color: Color {
        switch stage.status {
        case .done: return Theme.Palette.statusDone
        case .active: return Theme.Palette.signal
        default: return Theme.Palette.textTertiary
        }
    }

    private var symbol: String {
        switch stage.status {
        case .done: return "checkmark"
        case .active: return "circle.fill"
        default: return "circle"
        }
    }
}

/// The honesty contract, rendered: a hard boundary you can't miss.
private struct WallDivider: View {
    var caveat: String?

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: Theme.Space.s) {
                line
                Label("SIMULATION WALL", systemImage: "hand.raised.fill")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.Palette.gold)
                line
            }
            if let caveat {
                Text(caveat)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Theme.Space.m)
    }

    private var line: some View {
        Rectangle().fill(Theme.Palette.gold.opacity(0.5)).frame(height: 1)
    }
}

#Preview {
    FunnelView().environmentObject(PreviewData.store())
}
