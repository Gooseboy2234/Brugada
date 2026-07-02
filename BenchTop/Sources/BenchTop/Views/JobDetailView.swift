import SwiftUI

/// The "is this one run OK" view. Leads with the scientific metric that
/// matters for this job's type, then resources, then the log tail.
struct JobDetailView: View {
    @EnvironmentObject private var store: BenchTopStore
    var jobID: String
    @State private var showLog = false

    private var job: Job? { store.jobs.first { $0.id == jobID } }
    private var rig: Rig? {
        guard let job, let campaign = store.campaign(id: job.campaignID) else { return nil }
        return store.rig(id: campaign.rigID)
    }

    var body: some View {
        ScrollView {
            if let job {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    statusHeader(job)
                    if let metric = job.metric {
                        metricCard(job, metric)
                    }
                    if !job.tempSpark.isEmpty || !job.utilSpark.isEmpty || rig != nil {
                        resourcesCard(job)
                    }
                    if !job.logTail.isEmpty {
                        logCard(job)
                    }
                }
                .padding(Theme.Space.l)
            } else {
                ContentUnavailableView("Job not reported", systemImage: "terminal")
                    .padding(.top, 80)
            }
        }
        .background(Theme.Palette.ink)
        .navigationTitle(job?.tag ?? "Job")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func statusHeader(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack {
                StatusPill(status: job.status)
                Spacer()
                if let total = job.unitsTotal {
                    Text("\(job.unitsDone.formatted(.number.precision(.fractionLength(0...1)))) / \(Int(total)) \(job.unitLabel)")
                        .font(.btData(13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
                }
            }
            if let fraction = job.fractionDone {
                ProgressView(value: fraction).tint(job.status.tint)
            }
            HStack(spacing: Theme.Space.l) {
                if let eta = job.eta {
                    labelled("ETA", ETAFormat.string(eta))
                }
                if let rate = job.ratePerDay {
                    labelled("rate", "\(Int(rate)) \(job.unitLabel)/day")
                }
                Spacer()
            }
            if let eta = job.eta, let window = eta.windowMinutes {
                Text("based on last \(window) min")
                    .font(.system(size: 10.5)).foregroundStyle(Theme.Palette.textTertiary)
            }
            if job.status == .failed, let error = job.errorMessage {
                Text(error).font(.btCaption).foregroundStyle(Theme.Palette.statusFailed)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .btCard()
    }

    private func metricCard(_ job: Job, _ metric: JobMetric) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("The metric that matters · \(job.kind.readable)").btEyebrow()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(metric.value.formatted(.number.precision(.fractionLength(0...1))))
                    .font(.btData(30, weight: .bold)).foregroundStyle(Theme.Palette.textPrimary)
                Text(metric.unit).font(.btData(14)).foregroundStyle(Theme.Palette.textSecondary)
            }
            Text(metric.label).font(.btCaption).foregroundStyle(Theme.Palette.textSecondary)
            if !metric.sparkline.isEmpty {
                SparklineView(values: metric.sparkline, tint: Theme.Palette.signal)
                    .frame(height: 44)
            }
            if let note = metric.note {
                Text(note).font(.system(size: 11)).foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .btCard()
    }

    private func resourcesCard(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Resources").btEyebrow()
            if let rig {
                HStack(spacing: Theme.Space.l) {
                    labelled("temp", "\(Int(rig.tempC))°")
                    labelled("util", "\(Int(rig.utilPercent))%")
                    labelled("vram", "\(rig.vramUsedGB.formatted(.number.precision(.fractionLength(1))))/\(Int(rig.vramGB)) GB")
                    labelled("power", "\(Int(rig.powerW)) W")
                    Spacer()
                }
            }
            HStack(spacing: Theme.Space.l) {
                if !job.tempSpark.isEmpty {
                    sparkColumn("temp", job.tempSpark, Theme.Palette.statusWarning)
                }
                if !job.utilSpark.isEmpty {
                    sparkColumn("util", job.utilSpark, Theme.Palette.signal)
                }
            }
        }
        .btCard()
    }

    private func logCard(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showLog.toggle() }
            } label: {
                HStack {
                    Text("Log tail").btEyebrow()
                    Spacer()
                    Image(systemName: showLog ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if showLog {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(job.logTail.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.btData(10.5, weight: .regular))
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(Theme.Space.s)
                .background(Theme.Palette.ink, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
            }
        }
        .btCard()
    }

    private func labelled(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.btData(13, weight: .semibold)).foregroundStyle(Theme.Palette.textPrimary)
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.Palette.textTertiary)
        }
    }

    private func sparkColumn(_ label: String, _ values: [Double], _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.Palette.textTertiary)
            SparklineView(values: values, tint: tint, showsArea: false)
                .frame(width: 100, height: 24)
        }
    }
}

extension JobKind {
    var readable: String {
        switch self {
        case .md: return "MD"
        case .fep: return "FEP"
        case .docking: return "docking"
        case .folding: return "folding"
        case .other: return "job"
        }
    }
}

#Preview {
    NavigationStack {
        JobDetailView(jobID: "wt-s2").environmentObject(PreviewData.store())
    }
}
