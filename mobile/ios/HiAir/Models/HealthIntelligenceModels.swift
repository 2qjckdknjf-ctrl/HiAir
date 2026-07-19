import Foundation

struct HealthMetricSummaryPayload: Codable {
    let metricType: String
    let valueAvg: Double?
    let valueMin: Double?
    let valueMax: Double?
    let valueLatest: Double?
    let valueTotal: Double?
    let unit: String
    let sampleCount: Int
    let qualityState: String
    let hrvMethod: String?
    let sourceDeviceClass: String?
}

struct HealthSleepSummaryPayload: Codable {
    let localDate: String
    let totalMinutes: Int?
    let inBedMinutes: Int?
    let awakeMinutes: Int?
    let coreLightMinutes: Int?
    let deepMinutes: Int?
    let remMinutes: Int?
    let sleepStart: String?
    let sleepEnd: String?
    let qualityState: String
}

struct HealthSyncPayload: Codable {
    let profileId: String?
    let localDate: String
    let timezone: String
    let platform: String
    let source: String
    let clientSyncVersion: String
    let idempotencyKey: String?
    let metrics: [HealthMetricSummaryPayload]
    let sleep: HealthSleepSummaryPayload?
    let cursorMetadata: [String: String]
}

struct HealthSyncResponseDTO: Codable {
    let acceptedMetrics: Int
    let rejectedMetrics: [String]
    let sleepAccepted: Bool
    let syncStatus: String
}

struct HealthInsightCardDTO: Codable, Identifiable {
    var id: String { insightKey }
    let insightKey: String
    let title: String
    let observation: String
    let recommendation: String?
    let confidence: String
    let sampleSize: Int
    let windowDays: Int
    let supportingFactors: [String]?
    let limitations: [String]?
    let whyShown: String?
}

struct HealthInsightsBundleDTO: Codable {
    let profileId: String
    let generatedAt: String
    let today: [String: AnyCodableValue]?
    let trends: [HealthInsightCardDTO]
    let associations: [HealthInsightCardDTO]
    let insufficientData: [InsufficientDataCardDTO]
    let healthDataStatus: HealthDataStatusDTO?
}

struct InsufficientDataCardDTO: Codable, Identifiable {
    var id: String { key }
    let key: String
    let message: String
    let have: Int?
    let need: Int?
    let action: String?
}

struct HealthDataStatusDTO: Codable {
    let lastSuccessAt: String?
    let syncStatus: String?
    let metricDays: Int?
    let sleepDays: Int?
}

struct SymptomTaxonomyDTO: Codable {
    let consentVersion: String
    let safetyNotice: String
    let categories: [SymptomCategoryDTO]
    let count: Int
}

struct SymptomCategoryDTO: Codable, Identifiable {
    var id: String
    let label: String
    let symptoms: [SymptomTaxonomyItemDTO]
}

struct SymptomTaxonomyItemDTO: Codable, Identifiable {
    var id: String { symptomType }
    let symptomType: String
    let label: String
    let redFlag: Bool
}

struct ComprehensiveSymptomPayload: Codable {
    let profileId: String
    let symptomType: String
    let severity: Int
    let onsetAt: String?
    let durationMinutes: Int?
    let ongoing: Bool
    let note: String?
    let locationContext: String?
    let timezone: String?
    let customLabel: String?
}

struct ComprehensiveSymptomResponseDTO: Codable {
    let id: String
    let profileId: String
    let symptomType: String
    let severity: Int
    let redFlag: Bool
    let safetyNotice: String?
    let loggedAt: String
}

/// Lightweight Any JSON value for sparse today payload.
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case object([String: AnyCodableValue])
    case array([AnyCodableValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: AnyCodableValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([AnyCodableValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        }
    }
}
