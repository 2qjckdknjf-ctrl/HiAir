import SwiftUI

struct HiAirScreenWordmark: View {
    var suffix: String
    var suffixUsesGradient: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("HiAir")
                .font(HiAirTypography.displayLG)
                .foregroundStyle(
                    suffixUsesGradient
                        ? AnyShapeStyle(HiAirColors.Text.primary)
                        : AnyShapeStyle(HiAirColors.Spectrum.cyan)
                )
            Text(suffix)
                .font(HiAirTypography.displayLG)
                .foregroundStyle(
                    suffixUsesGradient
                        ? AnyShapeStyle(HiAirGradients.cta())
                        : AnyShapeStyle(HiAirColors.Text.primary)
                )
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct HiAirLivePill: View {
    var isLive: Bool
    var label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isLive ? HiAirColors.Risk.low : HiAirColors.Risk.moderate)
                .frame(width: 8, height: 8)
                .shadow(color: HiAirColors.Risk.low.opacity(isLive ? 0.9 : 0.2), radius: 5)
            Text(label)
                .font(HiAirTypography.caption.weight(.semibold))
                .foregroundStyle(HiAirColors.Text.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .hiAirGlassSurface(prominence: .compact, cornerRadius: HiAirRadius.chip)
    }
}

struct HiAirPlannerSummaryStrip: View {
    var riskLabel: String
    var riskLevel: String
    var outdoorRange: String
    var outdoorHint: String
    var ventilationRange: String
    var ventilationHint: String
    var lang: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            summaryColumn(
                title: HiAirDeepGlassCopy.t("today_risk", lang: lang)
            ) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(HiAirRiskStyle.color(for: riskLevel))
                        .frame(width: 8, height: 8)
                    Text(riskLabel)
                        .font(HiAirTypography.bodyMD.weight(.semibold))
                        .foregroundStyle(HiAirRiskStyle.color(for: riskLevel))
                }
            }
            divider
            summaryColumn(
                title: HiAirDeepGlassCopy.t("best_outdoor", lang: lang)
            ) {
                Label(outdoorRange, systemImage: "clock")
                    .font(HiAirTypography.bodyMD.weight(.semibold))
                    .foregroundStyle(HiAirColors.Spectrum.cyan)
                    .labelStyle(.titleAndIcon)
                Text(outdoorHint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(HiAirColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            divider
            summaryColumn(
                title: HiAirDeepGlassCopy.t("ventilation", lang: lang)
            ) {
                Label(ventilationRange, systemImage: "wind")
                    .font(HiAirTypography.bodyMD.weight(.semibold))
                    .foregroundStyle(HiAirColors.Spectrum.cyan)
                Text(ventilationHint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(HiAirColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(HiAirSpacing.md)
        .hiAirGlassSurface(prominence: .standard, glow: HiAirColors.Spectrum.cyan)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    private func summaryColumn<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(HiAirColors.Text.secondary)
                .tracking(0.4)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }
}

struct HiAirActionHintCard: View {
    var title: String
    var value: String
    var bodyText: String
    var icon: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(HiAirColors.Spectrum.cyan)
                    .frame(width: 36, height: 36)
                    .background(HiAirColors.Spectrum.cyan.opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(HiAirTypography.bodyMD.weight(.semibold))
                        .foregroundStyle(HiAirColors.Text.primary)
                    Text(value)
                        .font(HiAirTypography.caption.weight(.semibold))
                        .foregroundStyle(HiAirColors.Spectrum.cyan)
                    Text(bodyText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(HiAirColors.Text.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HiAirColors.Text.secondary)
            }
            .padding(14)
            .hiAirGlassSurface(prominence: .standard, glow: HiAirColors.Spectrum.cyan)
        }
        .buttonStyle(.plain)
    }
}

struct HiAirIntensitySelector: View {
    @Binding var value: Int
    var lang: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(HiAirDeepGlassCopy.t("intensity", lang: lang))
                .font(HiAirTypography.caption.weight(.semibold))
                .foregroundStyle(HiAirColors.Text.secondary)
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { level in
                    Button {
                        HiAirHaptics.chipSelect()
                        value = level
                    } label: {
                        Text("\(level)")
                            .font(HiAirTypography.bodyMD.weight(.semibold))
                            .foregroundStyle(HiAirColors.Text.primary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background {
                                if value == level {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(HiAirColors.Spectrum.cyan.opacity(0.18))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(HiAirColors.Spectrum.cyan.opacity(0.8), lineWidth: 1.5)
                                        )
                                        .shadow(color: HiAirColors.Spectrum.cyan.opacity(0.35), radius: 8)
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text(HiAirDeepGlassCopy.t("mild", lang: lang))
                Spacer()
                Text(HiAirDeepGlassCopy.t("spectrum.moderate", lang: lang))
                Spacer()
                Text(HiAirDeepGlassCopy.t("severe", lang: lang))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(HiAirColors.Text.secondary)
        }
    }
}

struct HiAirSymptomGlassChip: View {
    var title: String
    var icon: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(HiAirTypography.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? HiAirColors.Spectrum.cyan : HiAirColors.Text.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background {
                Capsule(style: .continuous)
                    .fill(selected ? HiAirColors.Spectrum.cyan.opacity(0.16) : Color.white.opacity(0.04))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                selected ? HiAirColors.Spectrum.cyan.opacity(0.85) : Color.white.opacity(0.14),
                                lineWidth: selected ? 1.6 : 1
                            )
                    )
                    .shadow(color: selected ? HiAirColors.Spectrum.cyan.opacity(0.35) : .clear, radius: 8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

struct HiAirSmartInsightCard: View {
    var bodyText: String
    var lang: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(HiAirDeepGlassCopy.t("smart_insight", lang: lang), systemImage: "sparkle")
                        .font(HiAirTypography.caption.weight(.semibold))
                        .foregroundStyle(HiAirColors.Spectrum.cyan)
                    Spacer()
                    Text(HiAirDeepGlassCopy.t("guidance", lang: lang))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(HiAirColors.Text.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
                Text(bodyText)
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirColors.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            HiAirColors.Spectrum.violet.opacity(0.55),
                            HiAirColors.Spectrum.electricBlue.opacity(0.18),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 36
                    )
                )
                .frame(width: 56, height: 56)
                .blur(radius: 2)
                .accessibilityHidden(true)
        }
        .padding(HiAirSpacing.md)
        .hiAirGlassSurface(prominence: .standard, glow: HiAirColors.Spectrum.violet)
    }
}

struct HiAirOutlineCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HiAirTypography.bodyMD.weight(.semibold))
            .foregroundStyle(HiAirColors.Text.primary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)
            .background(HiAirColors.Surface.bg2.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: HiAirRadius.cta, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: HiAirRadius.cta, style: .continuous)
                    .stroke(HiAirColors.Spectrum.violet.opacity(0.75), lineWidth: 1.2)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? HiAirMotion.pressScale : 1.0)
            .animation(.easeOut(duration: HiAirMotion.press), value: configuration.isPressed)
    }
}

enum HiAirDeepGlassTime {
    static func hour(from raw: String) -> Int? {
        if let date = HiAirHumanDate.date(fromISO: raw) {
            return Calendar.current.component(.hour, from: date)
        }
        let digits = raw.prefix(2)
        if digits.count == 2, digits.allSatisfy(\.isNumber) {
            return Int(digits)
        }
        return nil
    }
}
