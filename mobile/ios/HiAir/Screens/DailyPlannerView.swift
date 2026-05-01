import SwiftUI

@MainActor
final class DailyPlannerViewModel: ObservableObject {
    @Published var loading = false
    @Published var hourlyItems: [AirHourlyRiskPoint] = []
    @Published var safeWindows: [AirSafeWindow] = []
    @Published var ventilationWindows: [AirSafeWindow] = []
    @Published var statusText = "-"

    private let apiClient = APIClient.live()

    func refresh(profileId: String, userId: String, accessToken: String, language: String) async {
        loading = true
        defer { loading = false }
        do {
            let planner = try await apiClient.fetchAirDayPlan(
                profileId: profileId,
                userId: userId,
                accessToken: accessToken
            )
            hourlyItems = planner.hourlyRisk
            safeWindows = planner.safeWindows
            ventilationWindows = planner.ventilationWindows
            statusText = language == "en"
                ? "Loaded \(planner.hourlyRisk.count) hourly slots."
                : "Загружено \(planner.hourlyRisk.count) почасовых слотов."
        } catch {
            statusText = HiAirL10n.t("planner.failed", lang: language)
            hourlyItems = []
            safeWindows = []
            ventilationWindows = []
        }
    }
}

struct DailyPlannerView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = DailyPlannerViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(session.l("common.city_updated"))
                    .font(.caption)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                Text(session.l("planner.title"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(HiAirV2Theme.primaryText)

                Text(session.l("planner.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                Text(viewModel.statusText)
                    .font(.footnote)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                if !viewModel.hourlyItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.l("planner.hourly"))
                            .font(.headline)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .bottom, spacing: 3) {
                                ForEach(Array(viewModel.hourlyItems.prefix(24).enumerated()), id: \.offset) { index, item in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(color(for: item.overallRisk))
                                        .frame(width: 4, height: index % 2 == 0 ? 32 : 24)
                                        .overlay(alignment: .bottom) {
                                            if index % 6 == 0 {
                                                Text(String(item.hour.prefix(2)))
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(HiAirV2Theme.tertiaryText)
                                                    .offset(y: 11)
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("• \(keyEventLine())")
                                .font(.subheadline)
                                .foregroundStyle(HiAirV2Theme.primaryText)
                            if let firstWindow = viewModel.safeWindows.first {
                                Text("• \(session.l("planner.safe_windows")): \(firstWindow.start) → \(firstWindow.end)")
                                    .font(.subheadline)
                                    .foregroundStyle(HiAirV2Theme.secondaryText)
                            }
                            if let firstVent = viewModel.ventilationWindows.first {
                                Text("• \(session.l("planner.ventilation_windows")): \(firstVent.start) → \(firstVent.end)")
                                    .font(.subheadline)
                                    .foregroundStyle(HiAirV2Theme.secondaryText)
                            }
                        }
                    }
                    .v2Card()
                } else if !viewModel.safeWindows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.l("planner.safe_windows"))
                            .font(.headline)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        ForEach(viewModel.safeWindows, id: \.start) { window in
                            Text("\(window.type): \(window.start) → \(window.end)")
                                .font(.subheadline)
                                .foregroundStyle(HiAirV2Theme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .v2Card()
                }

                Button(viewModel.loading ? session.l("planner.loading") : session.l("planner.refresh")) {
                    Task {
                        guard !session.profileId.isEmpty else {
                            viewModel.statusText = session.l("planner.profile_required")
                            return
                        }
                        await viewModel.refresh(
                            profileId: session.profileId,
                            userId: session.userId,
                            accessToken: session.accessToken,
                            language: session.preferredLanguage
                        )
                    }
                }
                .buttonStyle(V2PrimaryButtonStyle())
                .disabled(viewModel.loading)

                Button(session.l("planner.apply")) {
                    session.selectedTab = 0
                }
                .buttonStyle(V2PrimaryButtonStyle())
            }
            .padding(16)
        }
        .v2PageBackground()
        .task {
            guard !session.profileId.isEmpty else {
                viewModel.statusText = session.l("planner.profile_required")
                return
            }
            await viewModel.refresh(
                profileId: session.profileId,
                userId: session.userId,
                accessToken: session.accessToken,
                language: session.preferredLanguage
            )
        }
    }

    private func color(for risk: String) -> Color {
        RiskAccentColor.color(for: risk)
    }

    private func keyEventLine() -> String {
        guard let maxRisk = viewModel.hourlyItems.max(by: { riskWeight($0.overallRisk) < riskWeight($1.overallRisk) }) else {
            return session.l("planner.fetch")
        }
        return "Peak \(maxRisk.overallRisk.uppercased()) at \(maxRisk.hour)"
    }

    private func riskWeight(_ risk: String) -> Int {
        switch risk.lowercased() {
        case "low":
            return 1
        case "moderate", "medium":
            return 2
        case "high":
            return 3
        case "very_high", "very high":
            return 4
        default:
            return 0
        }
    }
}
