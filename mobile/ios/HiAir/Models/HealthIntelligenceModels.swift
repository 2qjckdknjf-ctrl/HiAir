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

struct HealthSummaryMetricDTO: Codable, Identifiable {
    var id: String { metricType }
    let metricType: String
    let unit: String
    let valueAvg: Double?
    let valueMin: Double?
    let valueMax: Double?
    let valueLatest: Double?
    let valueTotal: Double?
    let sampleCount: Int?
    let qualityState: String?
    let hrvMethod: String?

    var displayValue: Double? {
        valueTotal ?? valueAvg ?? valueLatest
    }
}

struct HealthSummarySleepDTO: Codable {
    let localDate: String?
    let totalMinutes: Int?
    let inBedMinutes: Int?
    let awakeMinutes: Int?
    let coreLightMinutes: Int?
    let deepMinutes: Int?
    let remMinutes: Int?
    let qualityState: String?
}

struct HealthSummaryResponseDTO: Codable {
    let localDate: String
    let timezone: String?
    let metrics: [HealthSummaryMetricDTO]
    let sleep: HealthSummarySleepDTO?
    let dataDaysAvailable: Int?
}

struct SymptomTaxonomyDTO: Codable {
    let consentVersion: String
    let safetyNotice: String
    let categories: [SymptomCategoryDTO]
    let count: Int

    enum CodingKeys: String, CodingKey {
        case consentVersion
        case safetyNotice
        case severityNotice
        case categories
        case count
    }

    init(consentVersion: String, safetyNotice: String, categories: [SymptomCategoryDTO], count: Int) {
        self.consentVersion = consentVersion
        self.safetyNotice = safetyNotice
        self.categories = categories
        self.count = count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        consentVersion = try container.decodeIfPresent(String.self, forKey: .consentVersion) ?? "health-intelligence-v1"
        let safety = try container.decodeIfPresent(String.self, forKey: .safetyNotice)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let severity = try container.decodeIfPresent(String.self, forKey: .severityNotice)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let safety, !safety.isEmpty {
            safetyNotice = safety
        } else if let severity, !severity.isEmpty {
            // Production taxonomy historically shipped severityNotice; create responses use safetyNotice.
            safetyNotice = severity
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.safetyNotice,
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Missing safetyNotice/severityNotice"
                )
            )
        }
        categories = try container.decode([SymptomCategoryDTO].self, forKey: .categories)
        count = try container.decodeIfPresent(Int.self, forKey: .count)
            ?? categories.reduce(0) { $0 + $1.symptoms.count }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(consentVersion, forKey: .consentVersion)
        try container.encode(safetyNotice, forKey: .safetyNotice)
        try container.encode(safetyNotice, forKey: .severityNotice)
        try container.encode(categories, forKey: .categories)
        try container.encode(count, forKey: .count)
    }
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
    let frequency: String?
    let bodyContext: String?
    let suspectedTrigger: String?
    let activityAtOnset: String?
    let locationContext: String?
    let hydrationState: String?
    let medicationTaken: Bool?
    let note: String?
    let timezone: String?
    let customLabel: String?
    let clientRequestId: String?
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

struct CustomSymptomCreatePayload: Codable {
    let profileId: String
    let label: String
    let category: String
    let iconKey: String?
}

struct CustomSymptomResponseDTO: Codable {
    let id: String
    let symptomType: String
    let label: String
    let category: String
    let iconKey: String?
    let isHidden: Bool
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
