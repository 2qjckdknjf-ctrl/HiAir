import SwiftUI

/// Product-facing grid of today's health metrics from free `/api/v1/health/summary`.
struct HealthTodayMetricsView: View {
    @EnvironmentObject var session: AppSession
    let summary: HealthSummaryResponseDTO?
    let personalLoad: PersonalLoadSummary?

    private static let hiddenTypes: Set<String> = [
        "blood_pressure_systolic",
        "blood_pressure_diastolic",
        "blood_glucose",
        "weight",
        "height",
        "body_fat",
    ]

    private static let displayOrder: [String] = [
        "steps",
        "distance_walking_running",
        "active_energy",
        "basal_energy",
        "exercise_minutes",
        "stand_minutes",
        "flights_climbed",
        "workout_count",
        "workout_duration",
        "heart_rate",
        "resting_heart_rate",
        "walking_heart_rate_avg",
        "hrv_sdnn",
        "hrv_rmssd",
        "respiratory_rate",
        "oxygen_saturation",
        "body_temperature",
        "wrist_temperature",
        "vo2_max",
        "mindfulness_minutes",
        "walking_speed",
        "walking_step_length",
        "walking_asymmetry",
        "walking_double_support",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l("health.today.title"))
                .font(HiAirTypography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)

            if let load = personalLoad {
                Text("\(session.l("wearable.dashboard.load_risk")): \(loadLevelLabel(load.level))")
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                if let first = load.explanations.first,
                   !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(first)
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirV2Theme.tertiaryText)
                }
            }

            if metricRows.isEmpty && sleepRows.isEmpty {
                Text(session.l("health.today.empty"))
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(metricRows, id: \.0) { label, value in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .font(HiAirTypography.caption)
                                .foregroundStyle(HiAirV2Theme.tertiaryText)
                            Text(value)
                                .font(HiAirTypography.bodyMD)
                                .foregroundStyle(HiAirV2Theme.primaryText)
                                .accessibilityLabel("\(label) \(value)")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(HiAirColors.Overlay.subtle, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                if !sleepRows.isEmpty {
                    Text(session.l("health.today.sleep_stages"))
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirV2Theme.tertiaryText)
                        .padding(.top, 4)
                    ForEach(sleepRows, id: \.0) { label, value in
                        HStack {
                            Text(label)
                                .font(HiAirTypography.bodyMD)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Spacer()
                            Text(value)
                                .font(HiAirTypography.bodyMD)
                                .foregroundStyle(HiAirV2Theme.primaryText)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .v2Card()
    }

    private var metricRows: [(String, String)] {
        guard let summary else { return [] }
        let byType = Dictionary(uniqueKeysWithValues: summary.metrics.map { ($0.metricType, $0) })
        var rows: [(String, String)] = []
        var seenHRV = false
        for type in Self.displayOrder {
            if Self.hiddenTypes.contains(type) { continue }
            if type == "hrv_rmssd", seenHRV { continue }
            guard let metric = byType[type], let raw = metric.displayValue else { continue }
            if type == "hrv_sdnn" || type == "hrv_rmssd" { seenHRV = true }
            let label = session.l("health.metric.\(type == "hrv_rmssd" ? "hrv_sdnn" : type)")
            rows.append((label, format(metricType: type, value: raw, unit: metric.unit)))
        }
        return rows
    }

    private var sleepRows: [(String, String)] {
        guard let sleep = summary?.sleep else { return [] }
        var rows: [(String, String)] = []
        if let total = sleep.totalMinutes {
            rows.append((session.l("health.sleep.total"), "\(total) \(session.l("health.unit.min"))"))
        }
        if let deep = sleep.deepMinutes {
            rows.append((session.l("health.sleep.deep"), "\(deep) \(session.l("health.unit.min"))"))
        }
        if let rem = sleep.remMinutes {
            rows.append((session.l("health.sleep.rem"), "\(rem) \(session.l("health.unit.min"))"))
        }
        if let core = sleep.coreLightMinutes {
            rows.append((session.l("health.sleep.core"), "\(core) \(session.l("health.unit.min"))"))
        }
        if let awake = sleep.awakeMinutes {
            rows.append((session.l("health.sleep.awake"), "\(awake) \(session.l("health.unit.min"))"))
        }
        if let inBed = sleep.inBedMinutes {
            rows.append((session.l("health.sleep.in_bed"), "\(inBed) \(session.l("health.unit.min"))"))
        }
        return rows
    }

    private func format(metricType: String, value: Double, unit: String) -> String {
        switch metricType {
        case "distance_walking_running":
            let km = value / 1000.0
            return String(format: "%.1f %@", km, session.l("health.unit.km"))
        case "oxygen_saturation":
            return String(format: "%.0f%%", value)
        case "body_temperature", "wrist_temperature":
            return String(format: "%.1f %@", value, session.l("health.unit.celsius"))
        case "vo2_max":
            return String(format: "%.1f", value)
        default:
            if unit == "count" || unit == "min" || unit == "kcal" || unit == "bpm" || unit == "ms" {
                return "\(Int(value.rounded())) \(localizedUnit(unit))"
            }
            return String(format: "%.0f %@", value, localizedUnit(unit))
        }
    }

    private func localizedUnit(_ unit: String) -> String {
        let label: String
        switch unit {
        case "min": label = session.l("health.unit.min")
        case "kcal": label = session.l("health.unit.kcal")
        case "bpm": label = session.l("health.unit.bpm")
        case "ms": label = session.l("health.unit.ms")
        case "count": label = ""
        default: label = unit
        }
        return label.trimmingCharacters(in: .whitespaces)
    }

    private func loadLevelLabel(_ level: String) -> String {
        switch level {
        case "low": return session.l("wearable.load.low")
        case "moderate": return session.l("wearable.load.moderate")
        case "elevated", "high": return session.l("wearable.load.elevated")
        default: return session.l("wearable.load.none")
        }
    }
}
