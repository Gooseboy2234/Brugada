import SwiftUI

struct CampaignRoute: Hashable { var id: String }
struct JobRoute: Hashable { var id: String }

/// Where the science lives: the hypothesis, how far along the journey, the
/// live result you actually care about, the jobs, and the so-what verdict.
struct CampaignDetailView: View {
    @EnvironmentObject private var store: BenchTopStore
    var campaignID: String

    private var campaign: Campaign? { store.campaign(id: campaignID) }

    var body: some View {
        ScrollView {
            if let campaign {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    hypothesis(campaign)
                    funnelStrip(campaign)
                    if let result = campaign.liveResult {
                        liveResultCard(result)
                    }
                    jobsCard(campaign)
                    if let soWhat = campaign.soWhat {
                        soWhatCard(soWhat)
                    }
                }
                .padding(Theme.Space.l)
            } else {
                ContentUnavailableView("Campaign not reported", systemImage: "flask")
                    .padding(.top, 80)
            }
        }
        .background(Theme.Palette.ink)
        .navigationTitle(campaign?.title ?? "Campaign")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func hypothesis(_ campaign: Campaign) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("Hypothesis").btEyebrow()
            Text(campaign.hypothesis)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .btCard()
    }

    /// Compact "you are here" strip of the journey; full detail is the Funnel tab.
    private func funnelStrip(_ campaign: Campaign) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack {
                Text("Journey").btEyebrow()
                Spacer()
                if let active = campaign.activeStage {
                    Text("stage \(active.index) of \(campaign.funnel.map(\.index).max() ?? active.index)")
                        .font(.btData(10)).foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            HStack(spacing: 5) {
                ForEach(campaign.funnel) { stage in
                    Circle()
                        .fill(stageColor(stage.status))
                        .frame(width: 9, height: 9)
                        .overlay(Circle().strokeBorder(stage.isWall ? Theme.Palette.gold : .clear, lineWidth: 1.5))
                    if stage.id != campaign.funnel.last?.id {
                        Rectangle().fill(Theme.Palette.hairline).frame(height: 2)
                    }
                }
            }
            if let active = campaign.activeStage {
                Text("You are here: \(active.label)")
                    .font(.btCaption).foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .btCard()
    }

    private func liveResultCard(_ result: LiveResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Live result — \(result.metricLabel), \(result.unit)").btEyebrow()
            ForEach(result.series) { series in
                HStack(spacing: Theme.Space.m) {
                    Text(series.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(seriesColor(series.name))
                        .frame(width: 62, alignment: .leading)
                    SparklineView(values: series.sparkline, tint: seriesColor(series.name))
                        .frame(width: 84, height: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(series.value.formatted(.number.precision(.fractionLength(1)))) \(series.unit ?? result.unit)")
                            .font(.btData(13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
                        if let note = series.note {
                            Text(note).font(.system(size: 10.5)).foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .btCard()
    }

    private func jobsCard(_ campaign: Campaign) -> some View {
        let jobs = store.jobs(in: campaign)
        return VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("Jobs (\(jobs.count))").btEyebrow()
            if jobs.isEmpty {
                Text("No jobs reported yet.").font(.btCaption).foregroundStyle(Theme.Palette.textSecondary)
            } else {
                ForEach(jobs) { job in
                    NavigationLink(value: JobRoute(id: job.id)) {
                        CompactJobRow(job: job)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func soWhatCard(_ soWhat: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("So what").btEyebrow()
            Text(soWhat)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Palette.gold.opacity(0.4), lineWidth: 1))
    }

    private func stageColor(_ status: StageStatus) -> Color {
        switch status {
        case .done: return Theme.Palette.statusDone
        case .active: return Theme.Palette.signal
        default: return Theme.Palette.hairline
        }
    }

    /// Colour the science by meaning: the mutant reads as the problem, the
    /// rescue as the win, WT as the neutral reference.
    private func seriesColor(_ name: String) -> Color {
        let n = name.lowercased()
        if n.contains("rescue") { return Theme.Palette.statusDone }
        if n.contains("wt") || n.contains("wild") { return Theme.Palette.textSecondary }
        return Theme.Palette.statusFailed
    }
}

/// A tappable one-line job row used in campaign + rig lists.
struct CompactJobRow: View {
    var job: Job

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            ProgressRing(fraction: job.fractionDone, lineWidth: 4, tint: job.status.tint,
                         glyph: job.status == .done ? "✓" : (job.status == .failed ? "!" : nil))
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.tag).font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary).lineLimit(1)
                Text(subtitle).font(.btCaption)
                    .foregroundStyle(job.status == .failed ? Theme.Palette.statusFailed : Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Space.s)
            StatusPill(status: job.status)
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.Palette.textTertiary)
        }
        .padding(Theme.Space.m)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
    }

    private var subtitle: String {
        if job.status == .failed, let e = job.errorMessage { return e }
        if let total = job.unitsTotal { return "\(Int(job.unitsDone))/\(Int(total)) \(job.unitLabel)" }
        return "\(Int(job.unitsDone)) \(job.unitLabel)"
    }
}

#Preview {
    NavigationStack {
        CampaignDetailView(campaignID: "r104q-replicates")
            .environmentObject(PreviewData.store())
    }
}
