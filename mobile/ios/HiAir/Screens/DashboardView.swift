import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var loading = false
    @Published var riskLevel = "-"
    @Published var explanation = "-"
    @Published var headline = "-"
    @Published var actions: [String] = []
    @Published var nearestSafeWindow = "-"
    @Published var environmental: AirEnvironmentalInput?

    private let apiClient = APIClient.live()

    func refresh(
        userId: String,
        accessToken: String,
        profileId: String?,
        language: String
    ) async {
        loading = true
        defer { loading = false }
        guard let profileId, !profileId.isEmpty else {
            riskLevel = "unknown"
            headline = HiAirL10n.t("dashboard.empty.no_profile.title", lang: language)
            explanation = HiAirL10n.t("dashboard.empty.no_profile.body", lang: language)
            actions = []
            nearestSafeWindow = "-"
            environmental = nil
            return
        }
        do {
            let result = try await apiClient.fetchCurrentRisk(
                profileId: profileId,
                userId: userId,
                accessToken: accessToken
            )
            riskLevel = result.risk.overallRisk
            explanation = result.explanation
            headline = result.recommendation.headline
            actions = result.recommendation.actions
            environmental = result.environmental
            if let firstWindow = result.risk.safeWindows.first {
                nearestSafeWindow = "\(firstWindow.type): \(firstWindow.start) -> \(firstWindow.end)"
            } else {
                nearestSafeWindow = HiAirL10n.t("dashboard.no_safe_window", lang: language)
            }
        } catch {
            riskLevel = "error"
            headline = HiAirL10n.t("dashboard.error", lang: language)
            explanation = HiAirL10n.t("dashboard.empty.api_unavailable", lang: language)
            actions = []
            nearestSafeWindow = "-"
            environmental = nil
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = DashboardViewModel()
    @State private var activeInfoKey: InfoTerm?

    private var riskScore: Int {
        switch viewModel.riskLevel.lowercased() {
        case "low":
            return 24
        case "moderate", "medium":
            return 58
        case "high":
            return 79
        case "very_high":
            return 90
        default:
            return 58
        }
    }

    private var riskColor: Color {
        RiskAccentColor.color(for: viewModel.riskLevel)
    }

    private let weatherTitle = "Sunny 26C"
    private let moodTitle = "Calm"

    private var pm25Estimate: Double {
        switch viewModel.riskLevel.lowercased() {
        case "low":
            return 12
        case "moderate", "medium":
            return 32
        case "high":
            return 52
        case "very_high", "very high":
            return 85
        default:
            return 25
        }
    }

    private var freshnessLabel: String {
        viewModel.loading ? session.l("dashboard.freshness_stale") : session.l("dashboard.freshness_fresh")
    }

    private var safeWindows: [String] {
        if viewModel.nearestSafeWindow == "-" || viewModel.nearestSafeWindow.isEmpty {
            return ["06:00-08:00", "16:30-19:00", "22:00-23:00"]
        }
        return [viewModel.nearestSafeWindow, "16:30-19:00", "22:00-23:00"]
    }

    private var starterChecklist: [(id: String, titleKey: String)] {
        [
            ("risk", "dashboard.get_started.item.risk"),
            ("hourly", "dashboard.get_started.item.hourly"),
            ("recommendations", "dashboard.get_started.item.recommendations"),
            ("profile", "dashboard.get_started.item.profile"),
            ("notifications", "dashboard.get_started.item.notifications"),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuroraTokens.Spacing.md) {
                HStack(spacing: AuroraTokens.Spacing.xs) {
                    Button {
                        // Placeholder for location picker stage.
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                            Text(session.l("dashboard.location"))
                        }
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.08), in: Capsule())
                    }

                    HStack(spacing: 5) {
                        Circle()
                            .fill(viewModel.loading ? AuroraTokens.ColorPalette.riskModerate : AuroraTokens.ColorPalette.riskLow)
                            .frame(width: 6, height: 6)
                        Text(freshnessLabel)
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.tertiaryText)
                    }
                    Spacer()
                    Button {
                        session.selectedTab = 4
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(HiAirV2Theme.primaryText)
                    }
                    .accessibilityLabel(session.l("dashboard.profile_button"))
                }

                Text(session.l("dashboard.greeting"))
                    .font(AuroraTokens.Typography.displayLG)
                    .foregroundStyle(HiAirV2Theme.primaryText)

                Text(session.l("dashboard.improving"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                if !session.checklistHidden {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(session.l("dashboard.get_started.title"))
                                .font(AuroraTokens.Typography.titleMD)
                                .foregroundStyle(HiAirV2Theme.primaryText)
                            Spacer()
                            Button(session.l("dashboard.get_started.hide")) {
                                session.checklistHidden = true
                            }
                            .font(AuroraTokens.Typography.caption)
                        }
                        ForEach(starterChecklist, id: \.id) { item in
                            Button {
                                let next = !session.isChecklistItemDone(item.id)
                                session.markChecklistItem(item.id, done: next)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: session.isChecklistItemDone(item.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(session.isChecklistItemDone(item.id) ? HiAirV2Theme.accentStart : HiAirV2Theme.tertiaryText)
                                    Text(session.l(item.titleKey))
                                        .font(AuroraTokens.Typography.bodyMD)
                                        .foregroundStyle(HiAirV2Theme.secondaryText)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .v2Card()
                }

                if session.latitude == 0 && session.longitude == 0 {
                    Text(session.l("dashboard.empty.location_missing"))
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                        .v2Card()
                }

                if session.profileId.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.l("dashboard.empty.no_profile.title"))
                            .font(AuroraTokens.Typography.titleMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        Text(session.l("dashboard.empty.no_profile.body"))
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                        Button(session.l("dashboard.empty.no_profile.cta")) {
                            Task {
                                let created = await session.ensureProfileIdIfNeeded()
                                if created {
                                    session.markChecklistItem("profile", done: true)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(HiAirV2Theme.accentStart)
                    }
                    .v2Card()
                }

                VStack(alignment: .leading, spacing: AuroraTokens.Spacing.sm) {
                    HStack(spacing: 8) {
                        Text(session.l("dashboard.current_risk_title"))
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                        infoButton("dashboard.tooltip.risk_score")
                        Text(viewModel.riskLevel == "-" ? session.l("dashboard.badge_moderate") : viewModel.riskLevel.uppercased())
                            .font(AuroraTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(riskColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(riskColor.opacity(0.2), in: Capsule())
                    }

                    Text("\(riskScore)")
                        .font(AuroraTokens.Typography.displayXL)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                        .padding(.top, 8)

                    Text(session.l("dashboard.reason_code"))
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                        .lineLimit(2)

                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.14)).frame(height: 8)
                        Capsule()
                            .fill(
                                LinearGradient(colors: [HiAirV2Theme.accentStart, HiAirV2Theme.accentEnd], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: max(CGFloat(riskScore) * 3.1, 20), height: 8)
                    }
                }
                .v2Card()

                HStack(spacing: 12) {
                    GlobeAnchorView(riskLevel: viewModel.riskLevel, riskColor: riskColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(weatherTitle)
                            .font(AuroraTokens.Typography.titleMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        Text("Mood: \(moodTitle)")
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                        Text(session.l("dashboard.auto_updates"))
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.tertiaryText)
                    }
                    Spacer()
                }
                .padding(10)
                .v2Card()

                if let env = viewModel.environmental {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.l("dashboard.air_metrics"))
                            .font(AuroraTokens.Typography.titleMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        metricRow("dashboard.metric.aqi", value: "\(env.aqi)", tooltip: "dashboard.tooltip.aqi")
                        metricRow("dashboard.metric.pm25", value: String(format: "%.1f", env.pm25), tooltip: "dashboard.tooltip.pm25")
                        metricRow("dashboard.metric.ozone", value: String(format: "%.1f", env.ozone), tooltip: "dashboard.tooltip.ozone")
                        metricRow("dashboard.metric.heat_index", value: String(format: "%.1f°C", env.feelsLike), tooltip: "dashboard.tooltip.heat_index")
                        metricRow("dashboard.metric.humidity", value: String(format: "%.0f%%", env.humidity), tooltip: "dashboard.tooltip.heat_index")
                    }
                    .v2Card()
                } else if !viewModel.loading {
                    Text(session.l("dashboard.empty.api_unavailable"))
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                        .v2Card()
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(session.l("dashboard.do_now"))
                            .font(AuroraTokens.Typography.titleMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        infoButton("dashboard.recommendations_tooltip")
                    }

                    if viewModel.actions.isEmpty {
                        Group {
                            actionTile(icon: "drop.fill", text: session.l("dashboard.action_1"))
                            actionTile(icon: "cup.and.saucer.fill", text: session.l("dashboard.action_2"))
                            actionTile(icon: "figure.walk", text: session.l("dashboard.action_3"))
                        }
                    } else {
                        ForEach(Array(viewModel.actions.enumerated()), id: \.offset) { index, action in
                            actionTile(
                                icon: index == 0 ? "drop.fill" : (index == 1 ? "wind" : "figure.walk"),
                                text: action
                            )
                        }
                    }
                }
                .v2Card()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(session.l("dashboard.safe_windows"))
                            .font(AuroraTokens.Typography.titleMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        infoButton("dashboard.safe_windows_tooltip")
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(safeWindows, id: \.self) { window in
                                Text(window)
                                    .font(AuroraTokens.Typography.caption)
                                    .foregroundStyle(HiAirV2Theme.primaryText)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.08), in: Capsule())
                            }
                        }
                    }
                }
                .v2Card()

                Text(session.l("dashboard.tomorrow_hint"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
                    .padding(.horizontal, 4)

                Button(viewModel.loading ? session.l("dashboard.loading") : session.l("dashboard.recompute")) {
                    Task {
                        if session.profileId.isEmpty {
                            _ = await session.ensureProfileIdIfNeeded()
                        }
                        session.markChecklistItem("risk", done: true)
                        await viewModel.refresh(
                            userId: session.userId,
                            accessToken: session.accessToken,
                            profileId: session.profileId.isEmpty ? nil : session.profileId,
                            language: session.preferredLanguage
                        )
                    }
                }
                .buttonStyle(V2PrimaryButtonStyle())

                Button(session.l("dashboard.log_symptoms")) {
                    session.selectedTab = 3
                    session.markChecklistItem("recommendations", done: true)
                }
                .buttonStyle(V2PrimaryButtonStyle())
            }
            .padding(16)
        }
        .v2PageBackground()
        .overlay(
            AtmosphericParticles(pm25: pm25Estimate, tint: riskColor)
                .allowsHitTesting(false)
        )
        .task {
            if session.profileId.isEmpty {
                _ = await session.ensureProfileIdIfNeeded()
            }
            await viewModel.refresh(
                userId: session.userId,
                accessToken: session.accessToken,
                profileId: session.profileId.isEmpty ? nil : session.profileId,
                language: session.preferredLanguage
            )
            session.markChecklistItem("risk", done: true)
        }
        .sheet(item: $activeInfoKey) { item in
            InfoTextSheet(text: session.l(item.id), closeTitle: session.l("common.close"))
        }
    }

    @ViewBuilder
    private func actionTile(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(riskColor.opacity(0.18))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(riskColor)
                )
            Text(text)
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func infoButton(_ key: String) -> some View {
        Button {
            activeInfoKey = InfoTerm(id: key)
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(HiAirV2Theme.tertiaryText)
        }
        .buttonStyle(.plain)
    }

    private func metricRow(_ titleKey: String, value: String, tooltip: String) -> some View {
        HStack {
            Text(session.l(titleKey))
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            infoButton(tooltip)
            Spacer()
            Text(value)
                .font(AuroraTokens.Typography.bodyMD.weight(.semibold))
                .foregroundStyle(HiAirV2Theme.primaryText)
        }
    }
}

private struct InfoTerm: Identifiable {
    let id: String
}

private struct InfoTextSheet: View, Identifiable {
    let id = UUID()
    let text: String
    let closeTitle: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(16)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(closeTitle) { dismiss() }
                }
            }
        }
    }
}

private struct GlobeAnchorView: View {
    let riskLevel: String
    let riskColor: Color
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [riskColor.opacity(0.85), Color.cyan.opacity(0.32)],
                        center: .center,
                        startRadius: 6,
                        endRadius: 42
                    )
                )
                .frame(width: 72, height: 72)
                .shadow(color: riskColor.opacity(pulse ? 0.46 : 0.24), radius: pulse ? 18 : 12, x: 0, y: 6)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .scaleEffect(pulse ? 1.04 : 0.96)
                .rotationEffect(.degrees(pulse ? 360 : 0))
                .animation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true), value: pulse)
        }
        .onAppear {
            pulse = true
        }
    }

    private var pulseDuration: Double {
        switch riskLevel.lowercased() {
        case "low":
            return 4.0
        case "moderate", "medium":
            return 2.8
        case "high":
            return 2.0
        case "very_high", "very high":
            return 1.5
        default:
            return 3.0
        }
    }
}
