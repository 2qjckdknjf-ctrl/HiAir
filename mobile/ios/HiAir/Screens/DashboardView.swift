import SwiftUI

enum DashboardLoadState {
    case idle
    case loading
    case success
    case error
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var loadState: DashboardLoadState = .idle
    @Published var riskScore: Int?
    @Published var riskLevel = "-"
    @Published var explanation = "-"
    @Published var headline = "-"
    @Published var actions: [String] = []
    @Published var safeWindows: [String] = []
    @Published var morningBriefing = ""
    @Published var breakdownLines: [String] = []
    @Published var temperatureC: Double?
    @Published var aqi: Int?
    @Published var loading = false

    private let apiClient = APIClient.live()

    func refresh(
        userId: String,
        accessToken: String,
        profileId: String?,
        persona: String,
        lat: Double,
        lon: Double,
        language: String,
        isGuest: Bool
    ) async {
        loading = true
        loadState = .loading
        defer {
            loading = false
            if loadState == .loading { loadState = .error }
        }

        do {
            let briefing: MorningBriefingResponse
            let breakdown: RiskBreakdownResponse

            if !isGuest, let profileId, !profileId.isEmpty, !userId.isEmpty, !accessToken.isEmpty {
                let result = try await apiClient.fetchCurrentRisk(
                    profileId: profileId,
                    userId: userId,
                    accessToken: accessToken
                )
                riskLevel = result.risk.overallRisk
                explanation = result.explanation
                headline = result.recommendation.headline
                actions = result.recommendation.actions
                safeWindows = result.risk.safeWindows.map { "\($0.type): \($0.start) -> \($0.end)" }

                briefing = try await apiClient.fetchMorningBriefing(
                    profileId: profileId,
                    persona: persona,
                    lat: lat,
                    lon: lon,
                    userId: userId,
                    accessToken: accessToken
                )
                breakdown = try await apiClient.fetchRiskBreakdown(
                    profileId: profileId,
                    persona: persona,
                    lat: lat,
                    lon: lon,
                    userId: userId,
                    accessToken: accessToken
                )
            } else {
                briefing = try await apiClient.fetchMorningBriefingPublic(
                    persona: persona,
                    lat: lat,
                    lon: lon,
                    language: language
                )
                breakdown = try await apiClient.fetchRiskBreakdownPublic(persona: persona, lat: lat, lon: lon)
                let planner = try await apiClient.fetchDailyPlanner(persona: persona, lat: lat, lon: lon)
                riskLevel = breakdown.riskLevel
                headline = language == "en" ? "Your air & heat briefing" : "Ваш брифинг по воздуху и жаре"
                explanation = briefing.personalNote
                actions = []
                if let walk = briefing.bestWalkWindow {
                    actions.append(
                        language == "en" ? "Best walk window: \(walk)" : "Лучшее время для прогулки: \(walk)"
                    )
                }
                safeWindows = planner.safeWindows.map { "\($0.startHourIso) -> \($0.endHourIso)" }
            }

            riskScore = breakdown.totalScore
            morningBriefing = briefing.summary
            temperatureC = briefing.temperatureC
            aqi = briefing.aqi
            breakdownLines = breakdown.factors.map { factor in
                let label = language == "en" ? factor.labelEn : factor.labelRu
                return "+\(factor.points) \(label)"
            }
            loadState = .success
            AnalyticsService.shared.track(
                .morningBriefingOpened,
                userId: userId.isEmpty ? nil : userId,
                accessToken: accessToken.isEmpty ? nil : accessToken
            )
        } catch {
            loadState = .error
            riskLevel = "error"
            headline = HiAirL10n.t("dashboard.error", lang: language)
            explanation = language == "en" ? "Current risk request failed." : "Запрос текущего риска завершился ошибкой."
            actions = []
            safeWindows = []
            morningBriefing = ""
            breakdownLines = []
        }
    }

    func shareText(language: String) -> String {
        let score = riskScore.map(String.init) ?? "—"
        let walk = safeWindows.first ?? HiAirL10n.t("dashboard.no_safe_window", lang: language)
        let warning = morningBriefing.isEmpty ? explanation : morningBriefing
        return """
        \(HiAirL10n.t("share.title", lang: language))
        \(HiAirL10n.t("share.risk", lang: language)): \(score) (\(riskLevel))
        \(HiAirL10n.t("share.best_walk", lang: language)): \(walk)
        \(HiAirL10n.t("share.warning", lang: language)): \(warning)

        \(HiAirL10n.t("share.generated_by", lang: language))
        """
    }
}

struct DashboardView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = DashboardViewModel()
    @State private var sharePresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(session.l("dashboard.greeting"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(HiAirV2Theme.primaryText)

                Text(session.l("dashboard.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    Text(session.l("dashboard.morning_briefing"))
                        .font(.headline)
                    Text(briefingText)
                        .font(.subheadline)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                }
                .v2Card()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(session.l("dashboard.current_risk_title"))
                        Spacer()
                        Text(viewModel.riskLevel.uppercased())
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.yellow.opacity(0.18), in: Capsule())
                    }
                    Text(riskScoreText)
                        .font(.system(size: 56, weight: .bold))
                    Text([viewModel.headline, viewModel.explanation].filter { !$0.isEmpty && $0 != "-" }.joined(separator: "\n"))
                        .font(.subheadline)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                    if let temp = viewModel.temperatureC, let aqi = viewModel.aqi {
                        Text(session.preferredLanguage == "en"
                             ? "Temperature \(temp, specifier: "%.1f")°C • AQI \(aqi)"
                             : "Температура \(temp, specifier: "%.1f")°C • AQI \(aqi)")
                            .font(.caption)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                    }
                }
                .v2Card()

                if !viewModel.breakdownLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.l("dashboard.risk_breakdown"))
                            .font(.headline)
                        ForEach(viewModel.breakdownLines, id: \.self) { line in
                            Text(line).font(.subheadline)
                        }
                    }
                    .v2Card()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("dashboard.do_now")).font(.headline)
                    if viewModel.actions.isEmpty {
                        Text(session.l("dashboard.no_actions"))
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                    } else {
                        ForEach(viewModel.actions, id: \.self) { action in
                            Text("• \(action)").font(.subheadline)
                        }
                    }
                }
                .v2Card()

                VStack(alignment: .leading, spacing: 8) {
                    Text(session.l("dashboard.safe_windows")).font(.headline)
                    if viewModel.safeWindows.isEmpty {
                        Text(session.l("dashboard.no_safe_window"))
                    } else {
                        ForEach(viewModel.safeWindows, id: \.self) { window in
                            Text("• \(window)")
                        }
                    }
                }
                .v2Card()

                Button(viewModel.loading ? session.l("dashboard.loading") : session.l("dashboard.recompute")) {
                    Task { await refresh() }
                }
                .buttonStyle(V2PrimaryButtonStyle())

                Button(session.l("dashboard.share")) {
                    AnalyticsService.shared.track(
                        .shareCardClicked,
                        userId: session.userId.isEmpty ? nil : session.userId,
                        accessToken: session.accessToken.isEmpty ? nil : session.accessToken
                    )
                    sharePresented = true
                }
                    .buttonStyle(.bordered)

                Button(session.l("dashboard.log_symptoms")) { session.selectedTab = 2 }
                    .buttonStyle(V2PrimaryButtonStyle())
            }
            .padding(16)
        }
        .v2PageBackground()
        .sheet(isPresented: $sharePresented) {
            ShareLink(item: viewModel.shareText(language: session.preferredLanguage)) {
                Text(session.l("dashboard.share"))
            }
            .padding()
        }
        .task {
            AnalyticsService.shared.track(
                .dashboardOpened,
                userId: session.userId.isEmpty ? nil : session.userId,
                accessToken: session.accessToken.isEmpty ? nil : session.accessToken
            )
            await refresh()
        }
    }

    private var briefingText: String {
        if viewModel.loading { return session.l("dashboard.loading") }
        if !viewModel.morningBriefing.isEmpty { return viewModel.morningBriefing }
        return session.l("dashboard.fetch")
    }

    private var riskScoreText: String {
        switch viewModel.loadState {
        case .loading: return "…"
        case .success: return viewModel.riskScore.map(String.init) ?? "—"
        case .error: return "!"
        default: return "—"
        }
    }

    private func refresh() async {
        await viewModel.refresh(
            userId: session.userId,
            accessToken: session.accessToken,
            profileId: session.profileId.isEmpty ? nil : session.profileId,
            persona: session.persona,
            lat: session.latitude,
            lon: session.longitude,
            language: session.preferredLanguage,
            isGuest: session.isGuest
        )
    }
}
