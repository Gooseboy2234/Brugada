import Foundation

enum JobKind: String, Decodable, Hashable {
    case md, fep, docking, folding, other

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = JobKind(rawValue: raw) ?? .other
    }
}

enum JobStatus: String, Decodable, Hashable {
    case queued, running, done, failed, unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = JobStatus(rawValue: raw) ?? .unknown
    }
}

/// The one scientifically-meaningful heartbeat for a job's type — MD's
/// salt-bridge distance, FEP's ΔΔG, docking's best score. Mirrors
/// agent JobMetric.
struct JobMetric: Decodable, Hashable {
    var label: String
    var value: Double
    var unit: String
    var note: String?
    var sparkline: [Double]
}

/// One concrete run. Mirrors agent/benchtop_agent/models.py:Job.
struct Job: Identifiable, Decodable, Hashable {
    var id: String
    var campaignID: String
    var tag: String
    var kind: JobKind
    var status: JobStatus
    var unitsDone: Double
    var unitsTotal: Double?
    var unitLabel: String
    var ratePerDay: Double?
    var rateWindowMinutes: Int?
    var costSoFar: Double
    var metric: JobMetric?
    var tempSpark: [Double]
    var utilSpark: [Double]
    var logTail: [String]
    var errorMessage: String?

    var fractionDone: Double? {
        guard let unitsTotal, unitsTotal > 0 else { return nil }
        return min(max(unitsDone / unitsTotal, 0), 1)
    }

    /// Honest ETA from measured throughput (ns/day). Returns the interval and
    /// the confidence window it's based on, so the UI can say "based on last
    /// 20 min".
    var eta: (remaining: TimeInterval, windowMinutes: Int?)? {
        guard let unitsTotal, let ratePerDay, ratePerDay > 0, unitLabel == "ns" else { return nil }
        let remainingUnits = max(unitsTotal - unitsDone, 0)
        let days = remainingUnits / ratePerDay
        return (days * 86_400, rateWindowMinutes)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case campaignID = "campaign_id"
        case tag, kind, status
        case unitsDone = "units_done"
        case unitsTotal = "units_total"
        case unitLabel = "unit_label"
        case ratePerDay = "rate_per_day"
        case rateWindowMinutes = "rate_window_minutes"
        case costSoFar = "cost_so_far"
        case metric
        case tempSpark = "temp_spark"
        case utilSpark = "util_spark"
        case logTail = "log_tail"
        case errorMessage = "error_message"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        campaignID = try c.decode(String.self, forKey: .campaignID)
        tag = try c.decode(String.self, forKey: .tag)
        kind = try c.decode(JobKind.self, forKey: .kind)
        status = try c.decode(JobStatus.self, forKey: .status)
        unitsDone = try c.decode(Double.self, forKey: .unitsDone)
        unitsTotal = try c.decodeIfPresent(Double.self, forKey: .unitsTotal)
        unitLabel = try c.decode(String.self, forKey: .unitLabel)
        ratePerDay = try c.decodeIfPresent(Double.self, forKey: .ratePerDay)
        rateWindowMinutes = try c.decodeIfPresent(Int.self, forKey: .rateWindowMinutes)
        costSoFar = try c.decodeIfPresent(Double.self, forKey: .costSoFar) ?? 0
        metric = try c.decodeIfPresent(JobMetric.self, forKey: .metric)
        tempSpark = try c.decodeIfPresent([Double].self, forKey: .tempSpark) ?? []
        utilSpark = try c.decodeIfPresent([Double].self, forKey: .utilSpark) ?? []
        logTail = try c.decodeIfPresent([String].self, forKey: .logTail) ?? []
        errorMessage = try c.decodeIfPresent(String.self, forKey: .errorMessage)
    }

    // Memberwise init for previews (declaring init(from:) suppresses the synthesized one).
    init(id: String, campaignID: String, tag: String, kind: JobKind, status: JobStatus,
         unitsDone: Double, unitsTotal: Double?, unitLabel: String, ratePerDay: Double? = nil,
         rateWindowMinutes: Int? = nil, costSoFar: Double = 0, metric: JobMetric? = nil,
         tempSpark: [Double] = [], utilSpark: [Double] = [], logTail: [String] = [],
         errorMessage: String? = nil) {
        self.id = id; self.campaignID = campaignID; self.tag = tag; self.kind = kind
        self.status = status; self.unitsDone = unitsDone; self.unitsTotal = unitsTotal
        self.unitLabel = unitLabel; self.ratePerDay = ratePerDay; self.rateWindowMinutes = rateWindowMinutes
        self.costSoFar = costSoFar; self.metric = metric; self.tempSpark = tempSpark
        self.utilSpark = utilSpark; self.logTail = logTail; self.errorMessage = errorMessage
    }
}
