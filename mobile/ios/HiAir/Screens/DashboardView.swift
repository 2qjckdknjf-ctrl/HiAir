import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var loading = false
    @Published var riskLevel = "-"
    @Published var explanation = "-"
    @Published var headline = "-"
    @Published var actions: [String] = []
    @Published var nearestSafeWindow = "-"

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
            headline = language == "en" ? "Create a profile first" : "Сначала создайте профиль"
            explanation = HiAirL10n.t("planner.profile_required", lang: language)
            actions = []
            nearestSafeWindow = "-"
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
            if let firstWindow = result.risk.safeWindows.first {
                nearestSafeWindow = "\(firstWindow.type): \(firstWindow.start) -> \(firstWindow.end)"
            } else {
                nearestSafeWindow = HiAirL10n.t("dashboard.no_safe_window", lang: language)
            }
        } catch {
            riskLevel = "error"
            headline = HiAirL10n.t("dashboard.error", lang: language)
            explanation = language == "en" ? "Current risk request failed." : "Запрос текущего риска завершился ошибкой."
            actions = []
            nearestSafeWindow = "-"
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = DashboardViewModel()
    @State private var weatherPhase = 0
    private let weatherTicker = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

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
        switch viewModel.riskLevel.lowercased() {
        case "low": return .green
        case "moderate", "medium": return .yellow
        case "high", "very_high": return .orange
        default: return .secondary
        }
    }

    private var weatherTitle: String {
        switch weatherPhase {
        case 0: return "Sunny 26C"
        case 1: return "Heatwave 33C"
        default: return "Windy 22C"
        }
    }

    private var moodTitle: String {
        switch weatherPhase {
        case 0: return "Calm"
        case 1: return "Stressed"
        default: return "Energized"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(session.l("common.city_updated"))
                    .font(.caption)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                Text(session.l("dashboard.greeting"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(HiAirV2Theme.primaryText)

                Text(session.l("dashboard.improving"))
                    .font(.subheadline)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(session.l("dashboard.current_risk_title"))
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                        Text(viewModel.riskLevel == "-" ? session.l("dashboard.badge_moderate") : viewModel.riskLevel.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(riskColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(riskColor.opacity(0.18), in: Capsule())
                    }

                    Text("\(riskScore)")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(HiAirV2Theme.primaryText)

                    Text(viewModel.explanation)
                        .font(.subheadline)
                        .foregroundStyle(HiAirV2Theme.secondaryText)

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            weatherPhase == 0 ? .mint : (weatherPhase == 1 ? .orange : .cyan),
                                            weatherPhase == 0 ? .cyan : (weatherPhase == 1 ? .pink : .indigo)
                                        ],
                                        center: .center,
                                        startRadius: 4,
                                        endRadius: 36
                                    )
                                )
                                .frame(width: 70, height: 70)
                                .blur(radius: 0.5)
                                .shadow(color: .cyan.opacity(0.4), radius: 12, x: 0, y: 6)
                                .animation(.easeInOut(duration: 1.2), value: weatherPhase)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(weatherTitle)
                                .font(.headline)
                                .foregroundStyle(HiAirV2Theme.primaryText)
                            Text("Mood: \(moodTitle)")
                                .font(.subheadline)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Text(session.l("dashboard.auto_updates"))
                                .font(.caption)
                                .foregroundStyle(HiAirV2Theme.secondaryText.opacity(0.8))
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))

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

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("dashboard.do_now"))
                        .font(.headline)
                        .foregroundStyle(HiAirV2Theme.primaryText)

                    if viewModel.actions.isEmpty {
                        Group {
                            Text("• \(session.l("dashboard.action_1"))")
                            Text("• \(session.l("dashboard.action_2"))")
                            Text("• \(session.l("dashboard.action_3"))")
                        }
                        .font(.subheadline)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        ForEach(viewModel.actions, id: \.self) { action in
                            Text(action)
                                .font(.subheadline)
                                .foregroundStyle(HiAirV2Theme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .v2Card()

                VStack(alignment: .leading, spacing: 8) {
                    Text(session.l("dashboard.safe_windows"))
                        .font(.headline)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Text("• \(viewModel.nearestSafeWindow)")
                        .font(.subheadline)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                }
                .v2Card()

                Button(viewModel.loading ? session.l("dashboard.loading") : session.l("dashboard.recompute")) {
                    Task {
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
                    session.selectedTab = 2
                }
                .buttonStyle(V2PrimaryButtonStyle())
            }
            .padding(16)
        }
        .v2PageBackground()
        .onReceive(weatherTicker) { _ in
            weatherPhase = (weatherPhase + 1) % 3
        }
        .task {
            await viewModel.refresh(
                userId: session.userId,
                accessToken: session.accessToken,
                profileId: session.profileId.isEmpty ? nil : session.profileId,
                language: session.preferredLanguage
            )
        }
    }
}
