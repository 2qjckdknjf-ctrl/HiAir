import SwiftUI

// MARK: - Background

struct HiAirBackgroundView: View {
    var date: Date = Date()
    var showAtmosphere: Bool = false
    var atmosphereTint: Color = HiAirColors.Brand.orbCyan

    var body: some View {
        ZStack {
            HiAirGradients.timeOfDay(for: date)
                .ignoresSafeArea()
            if showAtmosphere {
                HiAirAtmosphericLayer(tint: atmosphereTint)
            }
        }
    }
}

struct HiAirTimeOfDayBackground: View {
    var body: some View {
        HiAirBackgroundView()
    }
}

struct HiAirAtmosphericLayer: View {
    let tint: Color
    @State private var phase: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.25)
            let radius = min(size.width, size.height) * 0.45
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [tint.opacity(0.12), .clear]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Brand mark

enum HiAirOrbPresentation {
    case brand
    case riskAccent(String)
}

struct HiAirOrbLogoView: View {
    var size: CGFloat = 96
    var riskLevel: String = "low"
    var animated: Bool = true
    var presentation: HiAirOrbPresentation = .brand

    @State private var pulse = false

    private var riskColor: Color {
        HiAirRiskStyle.color(for: riskLevel)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            HiAirColors.Brand.orbCyan.opacity(0.38),
                            HiAirColors.Brand.orbViolet.opacity(0.22),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: size * 0.08,
                        endRadius: size * 0.72
                    )
                )
                .frame(width: size * 1.28, height: size * 1.28)
                .blur(radius: 8)
                .opacity(animated && pulse ? 0.95 : 0.78)

            Image("HiAirOrb")
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: HiAirColors.Brand.orbCyan.opacity(0.45), radius: 14, x: 0, y: 4)
                .shadow(color: HiAirColors.Brand.orbViolet.opacity(0.35), radius: 22, x: 0, y: 10)
                .overlay(riskAccentRing)
                .scaleEffect(animated && pulse ? 1.03 : 1.0)
                .animation(
                    animated ? .easeInOut(duration: HiAirRiskStyle.orbPulseDuration(for: riskLevel)).repeatForever(autoreverses: true) : nil,
                    value: pulse
                )
        }
        .onAppear {
            if animated { pulse = true }
        }
        .accessibilityLabel("HiAir")
    }

    @ViewBuilder
    private var riskAccentRing: some View {
        if case .riskAccent(let level) = presentation {
            Circle()
                .stroke(HiAirRiskStyle.color(for: level).opacity(0.55), lineWidth: max(size * 0.04, 2))
                .padding(size * 0.04)
        }
    }
}

struct HiAirBrandHeader: View {
    var title: String = "HiAir"
    var subtitle: String? = "Breathe better. Live better."
    var showOrb: Bool = true
    var orbSize: CGFloat = 96
    var taglineUsesBrandAccent: Bool = true
    var compact: Bool = false

    var body: some View {
        Group {
            if compact {
                HStack(spacing: HiAirSpacing.sm) {
                    if showOrb {
                        Image("HiAirLogoMark")
                            .renderingMode(.original)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: min(orbSize, 48), height: min(orbSize, 48))
                    }
                    Image("HiAirWordmark")
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(maxWidth: 160, maxHeight: 36)
                        .accessibilityLabel(title)
                    Spacer(minLength: 0)
                }
            } else {
                VStack(spacing: HiAirSpacing.sm) {
                    if showOrb {
                        HiAirOrbLogoView(size: orbSize, animated: false, presentation: .brand)
                    }
                    Image("HiAirWordmark")
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(maxWidth: 280, maxHeight: 48)
                        .accessibilityLabel(title)
                    if let subtitle {
                        Text(subtitle)
                            .font(HiAirTypography.caption)
                            .foregroundStyle(taglineUsesBrandAccent ? HiAirColors.Cta.gradientStart : HiAirColors.Text.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Small horizontal mono lockup for Settings / legal footers on dark backgrounds.
struct HiAirBrandMonoFooter: View {
    var body: some View {
        Image("HiAirMonoLight")
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(maxWidth: 140, maxHeight: 40)
            .accessibilityLabel("HiAir")
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Buttons

struct HiAirGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HiAirTypography.titleMD)
            .foregroundStyle(HiAirColors.Cta.labelOnGradient)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)
            .background(HiAirGradients.cta())
            .clipShape(RoundedRectangle(cornerRadius: HiAirRadius.md, style: .continuous))
            .shadow(color: HiAirShadow.ctaGlow, radius: HiAirShadow.ctaRadius, x: 0, y: HiAirShadow.ctaYOffset)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(HiAirMotion.springSnappy, value: configuration.isPressed)
    }
}

struct HiAirSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HiAirTypography.bodyMD.weight(.medium))
            .foregroundStyle(HiAirColors.Text.primary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)
            .hiAirLiquidGlass(cornerRadius: HiAirRadius.md, variant: .regular)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(HiAirMotion.springSnappy, value: configuration.isPressed)
    }
}

// MARK: - Cards

struct HiAirCard<Content: View>: View {
    @ViewBuilder let content: Content
    var padding: CGFloat = HiAirSpacing.md

    var body: some View {
        content
            .padding(padding)
            .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: HiAirRadius.lg, style: .continuous)
            .fill(TimeOfDayBackground.surfacePrimary().opacity(0.94))
            .overlay(
                RoundedRectangle(cornerRadius: HiAirRadius.lg, style: .continuous)
                    .stroke(HiAirColors.Overlay.borderSoft, lineWidth: 1)
            )
    }
}

struct HiAirGlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(HiAirSpacing.md)
            .hiAirLiquidGlass(cornerRadius: HiAirRadius.lg, variant: .regular)
            .hiAirLiquidGlassMaterialize()
    }
}

struct HiAirMetricCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil

    var body: some View {
        HiAirCard {
            VStack(alignment: .leading, spacing: HiAirSpacing.xxs) {
                Text(title)
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirColors.Text.secondary)
                Text(value)
                    .font(HiAirTypography.titleLG)
                    .foregroundStyle(HiAirColors.Text.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirColors.Text.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Risk

struct HiAirRiskChip: View {
    let label: String
    let riskLevel: String

    private var color: Color { HiAirRiskStyle.color(for: riskLevel) }

    var body: some View {
        Text(label)
            .font(HiAirTypography.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.2), in: Capsule())
            .accessibilityLabel(label)
    }
}

struct HiAirRiskBadge: View {
    let score: Int
    let label: String
    let riskLevel: String
    var reason: String? = nil

    private var color: Color { HiAirRiskStyle.color(for: riskLevel) }

    var body: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            HStack(spacing: HiAirSpacing.xs) {
                Text(label)
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirColors.Text.secondary)
                HiAirRiskChip(label: riskLevel.uppercased(), riskLevel: riskLevel)
            }
            Text("\(score)")
                .font(HiAirTypography.displayXL)
                .foregroundStyle(HiAirColors.Text.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let reason {
                Text(reason)
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirColors.Text.secondary)
                    .lineLimit(3)
            }
        }
    }
}

/// Aurora ring gauge — signature dashboard hero (mockup-aligned).
struct HiAirRiskGaugeView: View {
    let score: Int
    let sectionLabel: String
    let statusLabel: String
    let riskLevel: String
    var reason: String? = nil
    var diameter: CGFloat = 200

    private var accent: Color { HiAirRiskStyle.color(for: riskLevel) }
    private var progress: CGFloat { CGFloat(min(max(score, 0), 100)) / 100 }

    var body: some View {
        VStack(spacing: HiAirSpacing.md) {
            Text(sectionLabel)
                .font(HiAirTypography.caption)
                .foregroundStyle(HiAirColors.Text.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .stroke(HiAirColors.Overlay.borderSoft, lineWidth: 12)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                HiAirColors.Brand.orbViolet,
                                HiAirColors.Cta.gradientEnd,
                                HiAirColors.Cta.gradientStart,
                                accent,
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accent.opacity(0.4), radius: 14, x: 0, y: 4)

                VStack(spacing: 6) {
                    Text("\(score)")
                        .font(.system(size: diameter * 0.34, weight: .semibold, design: .rounded))
                        .foregroundStyle(HiAirColors.Text.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(accent)
                            .frame(width: 8, height: 8)
                        Text(statusLabel)
                            .font(HiAirTypography.bodyMD.weight(.medium))
                            .foregroundStyle(HiAirColors.Text.primary)
                    }
                }
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity)

            if let reason {
                Text(reason)
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirColors.Text.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct HiAirSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(HiAirTypography.titleMD)
                .foregroundStyle(HiAirColors.Text.primary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirColors.Cta.gradientStart)
            }
        }
    }
}

// MARK: - States

struct HiAirEmptyStateView: View {
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: HiAirSpacing.md) {
            HiAirOrbLogoView(size: 72, animated: false, presentation: .brand)
            Text(title)
                .font(HiAirTypography.titleMD)
                .foregroundStyle(HiAirColors.Text.primary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(HiAirGradientButtonStyle())
            }
        }
        .padding(HiAirSpacing.lg)
        .frame(maxWidth: .infinity)
    }
}

struct HiAirLoadingView: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: HiAirSpacing.md) {
            ProgressView()
                .tint(HiAirColors.Cta.gradientStart)
            Text(message)
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.secondary)
        }
        .padding(HiAirSpacing.lg)
        .frame(maxWidth: .infinity)
    }
}

struct HiAirErrorView: View {
    let title: String
    let message: String
    var retryTitle: String? = nil
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: HiAirSpacing.md) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(HiAirColors.Feedback.errorSoft)
            Text(title)
                .font(HiAirTypography.titleMD)
                .foregroundStyle(HiAirColors.Text.primary)
            Text(message)
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.secondary)
                .multilineTextAlignment(.center)
            if let retryTitle, let onRetry {
                Button(retryTitle, action: onRetry)
                    .buttonStyle(HiAirSecondaryButtonStyle())
            }
        }
        .padding(HiAirSpacing.lg)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Screen wrapper

struct HiAirScreenContainer<Content: View>: View {
    var atmosphereTint: Color = HiAirColors.Brand.orbCyan
    @ViewBuilder let content: (CGFloat, HiAirLayoutMode) -> Content

    var body: some View {
        HiAirAdaptiveLayout { width, mode in
            ScrollView {
                content(width, mode)
                    .hiAirContentWidth(for: width)
                    .hiAirScreenPadding(for: width)
                    .padding(.bottom, HiAirSpacing.xl)
            }
            .background {
                HiAirBackgroundView(showAtmosphere: true, atmosphereTint: atmosphereTint)
            }
        }
    }
}

extension View {
    func hiAirChipSurface(isSelected: Bool = false) -> some View {
        background(
            isSelected ? HiAirColors.Cta.gradientStart.opacity(0.35) : HiAirColors.Overlay.subtle,
            in: Capsule()
        )
    }

    func hiAirTileSurface(isSelected: Bool = false) -> some View {
        background(
            isSelected ? HiAirColors.Cta.gradientStart.opacity(0.26) : HiAirColors.Overlay.subtle,
            in: RoundedRectangle(cornerRadius: HiAirRadius.sm + 4)
        )
    }

    func hiAirInputSurface() -> some View {
        hiAirLiquidGlass(cornerRadius: HiAirRadius.sm + 4, variant: .clear)
    }

    func hiAirPageBackground() -> some View {
        background(HiAirGradients.timeOfDay().ignoresSafeArea())
    }
}
