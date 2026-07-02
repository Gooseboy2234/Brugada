import Foundation

enum AlertKind: String, Decodable, Hashable {
    case jobDone = "job_done"
    case campaign
    case jobFailed = "job_failed"
    case thermal
    case budget
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AlertKind(rawValue: raw) ?? .unknown
    }
}

enum AlertSeverity: String, Decodable, Hashable {
    case good, warning, critical, unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AlertSeverity(rawValue: raw) ?? .unknown
    }
}

/// Rare and meaningful — either good news you were waiting for or something
/// that needs your hand. Mirrors agent Alert.
struct Alert: Identifiable, Decodable, Hashable {
    var id: String
    var kind: AlertKind
    var severity: AlertSeverity
    var title: String
    var detail: String?
    var rigID: String? = nil

    private enum CodingKeys: String, CodingKey {
        case id, kind, severity, title, detail
        case rigID = "rig_id"
    }
}
