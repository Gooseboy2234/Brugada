import Foundation

/// One stage of a campaign's screening funnel, e.g. "Docked" -> 1,200,000.
struct FunnelStage: Codable, Hashable, Identifiable {
    var name: String
    var count: Int

    var id: String { name }
}

/// A drug-discovery campaign against a target, made up of one or more jobs
/// and a funnel describing how the candidate pool has been pruned.
struct Campaign: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var target: String
    var funnel: [FunnelStage]

    var startCount: Int? { funnel.first?.count }
    var latestCount: Int? { funnel.last?.count }
}
