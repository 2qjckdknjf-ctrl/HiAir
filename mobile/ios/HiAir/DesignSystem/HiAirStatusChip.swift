import SwiftUI

/// Air-quality / window status levels from the UX audit (Excellent → Bad).
/// Also accepts legacy risk engine tokens (`low`, `moderate`, `high`, `very_high`).
enum HiAirStatusLevel: String, CaseIterable, Equatable {
    case excellent
    case good
    case moderate
    case bad

    init(riskLevel: String) {
        switch riskLevel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "excellent", "отлично", "excellent_air":
            self = .excellent
        case "good", "low", "хорошо":
            self = .good
        case "moderate", "medium", "умеренно", "средний":
            self = .moderate
        case "bad", "poor", "high", "very_high", "very high", "плохо", "высокий":
            self = .bad
        default:
            self = .moderate
        }
    }

    /// Maps to existing risk palette for consistent Aurora Calm colors.
    var riskToken: String {
        switch self {
        case .excellent, .good:
            return "low"
        case .moderate:
            return "moderate"
        case .bad:
            return "high"
        }
    }

    var color: Color {
        switch self {
        case .excellent:
            return HiAirColors.Brand.orbTeal
        case .good:
            return HiAirColors.Risk.low
        case .moderate:
            return HiAirColors.Risk.moderate
        case .bad:
            return HiAirColors.Risk.high
        }
    }
}

/// Status tag for planner windows and chart legends (audit StatusChip).
struct HiAirStatusChip: View {
    let level: HiAirStatusLevel
    let label: String

    init(level: HiAirStatusLevel, label: String) {
        self.level = level
        self.label = label
    }

    init(riskLevel: String, label: String) {
        self.level = HiAirStatusLevel(riskLevel: riskLevel)
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(HiAirTypography.caption.weight(.semibold))
            .foregroundStyle(level.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(minHeight: 28)
            .background(level.color.opacity(0.2), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isStaticText)
    }
}
