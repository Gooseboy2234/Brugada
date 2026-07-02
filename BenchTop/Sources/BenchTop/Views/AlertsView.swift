import SwiftUI

/// Rare and meaningful only — good news you were waiting for, or something
/// that needs your hand. Sorted most-urgent first (the agent does the ranking).
struct AlertsView: View {
    @EnvironmentObject private var store: BenchTopStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.s) {
                    if store.alerts.isEmpty {
                        ContentUnavailableView {
                            Label("All quiet", systemImage: "checkmark.circle")
                        } description: {
                            Text("Nothing needs your hand. Normal is silent.")
                        }
                        .padding(.top, 80)
                    } else {
                        ForEach(store.alerts) { alert in
                            AlertRow(alert: alert)
                        }
                    }
                }
                .padding(Theme.Space.l)
            }
            .background(Theme.Palette.ink)
            .navigationTitle("Alerts")
            #if os(iOS)
            .toolbarBackground(Theme.Palette.ink, for: .navigationBar)
            #endif
            .refreshable { await store.refresh() }
        }
    }
}

private struct AlertRow: View {
    var alert: Alert

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Image(systemName: alert.severity.symbol)
                .font(.system(size: 16))
                .foregroundStyle(alert.severity.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                if let detail = alert.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.btCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(alert.severity.tint.opacity(0.35), lineWidth: 1)
        )
    }
}

#Preview {
    AlertsView().environmentObject(PreviewData.store())
}
