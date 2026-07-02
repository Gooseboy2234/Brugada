import SwiftUI

/// The glance — one card per rig. Each card answers, in priority order:
/// is the science moving (active campaign + %), is the money safe (spend),
/// is the machine healthy (temp) — machine last, on purpose.
struct HomeView: View {
    @EnvironmentObject private var store: BenchTopStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.m) {
                    if store.rigs.isEmpty {
                        waiting
                    } else {
                        ForEach(store.rigs) { rig in
                            RigCardView(rig: rig)
                        }
                    }
                    if let lastError = store.lastError, store.rigs.isEmpty {
                        Label(lastError, systemImage: "exclamationmark.triangle")
                            .font(.btCaption).foregroundStyle(Theme.Palette.statusWarning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(Theme.Space.l)
            }
            .background(Theme.Palette.ink)
            .navigationTitle("BenchTop")
            #if os(iOS)
            .toolbarBackground(Theme.Palette.ink, for: .navigationBar)
            #endif
            .navigationDestination(for: CampaignRoute.self) { CampaignDetailView(campaignID: $0.id) }
            .navigationDestination(for: JobRoute.self) { JobDetailView(jobID: $0.id) }
            .refreshable { await store.refresh() }
        }
    }

    private var waiting: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: "server.rack").font(.system(size: 34)).foregroundStyle(Theme.Palette.signal)
            Text("Waiting for a rig").font(.btHeadline).foregroundStyle(Theme.Palette.textPrimary)
            Text("Start benchtop_agent on your rig, or set its address in Settings.")
                .font(.btCaption).foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

struct RigCardView: View {
    @EnvironmentObject private var store: BenchTopStore
    var rig: Rig

    private var campaign: Campaign? { store.activeCampaign(on: rig) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            // Header — the machine, named but understated.
            HStack(spacing: Theme.Space.s) {
                Image(systemName: rig.isCloud ? "cloud" : "desktopcomputer")
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text(rig.name).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(rig.gpuModel).font(.btCaption).foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1)
                Spacer()
            }

            // 1 — the science.
            if let campaign {
                NavigationLink(value: CampaignRoute(id: campaign.id)) {
                    campaignBlock(campaign)
                }
                .buttonStyle(.plain)
            } else {
                Text("Idle — no active campaign")
                    .font(.btCaption).foregroundStyle(Theme.Palette.textSecondary)
            }

            Divider().overlay(Theme.Palette.hairline)

            // 2 — the money, honest about home = free.
            HStack(spacing: Theme.Space.s) {
                Image(systemName: rig.isCloud ? "dollarsign.circle" : "bolt")
                    .font(.system(size: 12)).foregroundStyle(Theme.Palette.textTertiary)
                Text(rig.spendSummary).font(.btData(11)).foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                if let fraction = rig.budgetFraction {
                    ProgressView(value: fraction)
                        .tint(fraction >= 0.8 ? Theme.Palette.statusWarning : Theme.Palette.signal)
                        .frame(width: 70)
                }
            }

            // 3 — the machine + alerts, least prominent.
            HStack(spacing: Theme.Space.l) {
                machineStat("temp", "\(Int(rig.tempC))°", rig.tempC >= 80 ? Theme.Palette.statusWarning : Theme.Palette.textSecondary)
                machineStat("util", "\(Int(rig.utilPercent))%", Theme.Palette.textSecondary)
                machineStat("vram", "\(rig.vramUsedGB.formatted(.number.precision(.fractionLength(1))))/\(Int(rig.vramGB))", Theme.Palette.textSecondary)
                Spacer()
                alertBadge
            }
        }
        .btCard()
    }

    private func campaignBlock(_ campaign: Campaign) -> some View {
        let running = store.jobsRunning(in: campaign)
        let jobs = store.jobs(in: campaign)
        let doneCount = jobs.filter { $0.status == .done }.count
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: running.isEmpty ? "pause.fill" : "play.fill")
                    .font(.system(size: 11)).foregroundStyle(Theme.Palette.signal)
                Text(campaign.title).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                if let pct = campaign.percentComplete {
                    Text(pct, format: .percent.precision(.fractionLength(0)))
                        .font(.btData(13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
                }
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.Palette.textTertiary)
            }
            if let pct = campaign.percentComplete {
                ProgressView(value: pct).tint(Theme.Palette.signal)
            }
            HStack(spacing: 8) {
                Text("\(doneCount)/\(jobs.count) jobs done · \(running.count) running")
                    .font(.btCaption).foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                if let eta = store.batchETA(for: campaign) {
                    Text(ETAFormat.string(eta)).font(.btData(11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.signal)
                }
            }
        }
    }

    private func machineStat(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(value).font(.btData(11)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.Palette.textTertiary)
        }
    }

    private var alertBadge: some View {
        let rigAlerts = store.alerts(on: rig)
        let needsHand = rigAlerts.filter { $0.severity != .good }.count
        return Group {
            if needsHand > 0 {
                Label("\(needsHand)", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.Palette.statusWarning)
            } else {
                Label("0", systemImage: "checkmark.circle").font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }
}

/// Honest ETA formatting, including the confidence window when known.
enum ETAFormat {
    private static let f: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day, .hour, .minute]
        f.unitsStyle = .abbreviated
        f.maximumUnitCount = 2
        return f
    }()

    static func string(_ eta: (remaining: TimeInterval, windowMinutes: Int?)) -> String {
        let base = f.string(from: eta.remaining) ?? "—"
        return "ETA \(base)"
    }

    static func detailed(_ eta: (remaining: TimeInterval, windowMinutes: Int?)) -> String {
        let base = string(eta)
        if let w = eta.windowMinutes { return "\(base) · based on last \(w) min" }
        return base
    }
}

#Preview {
    HomeView().environmentObject(PreviewData.store())
}
