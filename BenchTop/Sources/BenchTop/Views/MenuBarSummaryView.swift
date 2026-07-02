#if os(macOS)
import SwiftUI

/// Compact menu bar content — lets a Mac near the rig act as an ambient
/// monitor without a window open. Science first: the active campaign and its
/// progress, then the honest spend line, then temp.
struct MenuBarSummaryView: View {
    @EnvironmentObject private var store: BenchTopStore

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if store.rigs.isEmpty {
                Text("No rig reported").font(.caption).foregroundStyle(Theme.Palette.textSecondary)
            } else {
                ForEach(store.rigs) { rig in
                    let campaign = store.activeCampaign(on: rig)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(rig.name).font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Spacer()
                            if let pct = campaign?.percentComplete {
                                Text(pct, format: .percent.precision(.fractionLength(0)))
                                    .font(.btData(12)).foregroundStyle(Theme.Palette.signal)
                            }
                        }
                        if let campaign {
                            Text(campaign.title).font(.btCaption)
                                .foregroundStyle(Theme.Palette.textSecondary).lineLimit(1)
                        }
                        HStack {
                            Text(rig.spendSummary).font(.btData(10))
                                .foregroundStyle(Theme.Palette.textTertiary).lineLimit(1)
                            Spacer()
                            Text("\(Int(rig.tempC))°")
                                .font(.btData(10))
                                .foregroundStyle(rig.tempC >= 80 ? Theme.Palette.statusWarning : Theme.Palette.textTertiary)
                        }
                    }
                    if rig.id != store.rigs.last?.id { Divider() }
                }
            }

            let needsHand = store.alerts.filter { $0.severity != .good }.count
            if needsHand > 0 {
                Divider()
                Label("\(needsHand) alert\(needsHand == 1 ? "" : "s") need attention", systemImage: "exclamationmark.triangle.fill")
                    .font(.btCaption).foregroundStyle(Theme.Palette.statusWarning)
            }

            if let lastError = store.lastError {
                Divider()
                Text(lastError).font(.btCaption).foregroundStyle(Theme.Palette.statusWarning).lineLimit(2)
            }
        }
        .padding(Theme.Space.m)
        .frame(width: 250)
    }
}
#endif
