import Foundation

enum StageStatus: String, Decodable, Hashable {
    case done, active, upcoming, unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = StageStatus(rawValue: raw) ?? .unknown
    }
}

/// One rung of the cure-journey funnel. `isWall` marks the SIMULATION WALL —
/// the hard boundary between what a GPU can answer and what only a wet lab
/// can. `caveat` is the honest per-stage footnote.
struct Stage: Decodable, Hashable, Identifiable {
    var index: Int
    var label: String
    var status: StageStatus
    var detail: String?
    var isWall: Bool
    var caveat: String?

    var id: Int { index }

    private enum CodingKeys: String, CodingKey {
        case index, label, status, detail, caveat
        case isWall = "is_wall"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        index = try c.decode(Int.self, forKey: .index)
        label = try c.decode(String.self, forKey: .label)
        status = try c.decode(StageStatus.self, forKey: .status)
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
        isWall = try c.decodeIfPresent(Bool.self, forKey: .isWall) ?? false
        caveat = try c.decodeIfPresent(String.self, forKey: .caveat)
    }

    init(index: Int, label: String, status: StageStatus, detail: String? = nil,
         isWall: Bool = false, caveat: String? = nil) {
        self.index = index; self.label = label; self.status = status
        self.detail = detail; self.isWall = isWall; self.caveat = caveat
    }
}

/// One system's trace in a campaign's live result (WT / R104Q / rescued).
struct ResultSeries: Decodable, Hashable, Identifiable {
    var name: String
    var value: Double
    var unit: String?
    var note: String?
    var sparkline: [Double]

    var id: String { name }
}

/// The number you actually care about, live.
struct LiveResult: Decodable, Hashable {
    var metricLabel: String
    var unit: String
    var series: [ResultSeries]

    private enum CodingKeys: String, CodingKey {
        case metricLabel = "metric_label"
        case unit, series
    }
}

/// One scientific question against a target. Mirrors agent Campaign.
struct Campaign: Identifiable, Decodable, Hashable {
    var id: String
    var rigID: String
    var title: String
    var hypothesis: String
    var funnel: [Stage]
    var liveResult: LiveResult?
    var soWhat: String?
    var percentComplete: Double?

    var activeStage: Stage? { funnel.first { $0.status == .active } }

    private enum CodingKeys: String, CodingKey {
        case id
        case rigID = "rig_id"
        case title, hypothesis, funnel
        case liveResult = "live_result"
        case soWhat = "so_what"
        case percentComplete = "percent_complete"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        rigID = try c.decode(String.self, forKey: .rigID)
        title = try c.decode(String.self, forKey: .title)
        hypothesis = try c.decode(String.self, forKey: .hypothesis)
        funnel = try c.decode([Stage].self, forKey: .funnel)
        liveResult = try c.decodeIfPresent(LiveResult.self, forKey: .liveResult)
        soWhat = try c.decodeIfPresent(String.self, forKey: .soWhat)
        percentComplete = try c.decodeIfPresent(Double.self, forKey: .percentComplete)
    }

    init(id: String, rigID: String, title: String, hypothesis: String, funnel: [Stage],
         liveResult: LiveResult? = nil, soWhat: String? = nil, percentComplete: Double? = nil) {
        self.id = id; self.rigID = rigID; self.title = title; self.hypothesis = hypothesis
        self.funnel = funnel; self.liveResult = liveResult; self.soWhat = soWhat
        self.percentComplete = percentComplete
    }
}
