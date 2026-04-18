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

                if !viewModel.safeWindows.isEmpty {
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

                if !viewModel.ventilationWindows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.l("planner.ventilation_windows"))
                            .font(.headline)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        ForEach(viewModel.ventilationWindows, id: \.start) { window in
                            Text("\(window.start) → \(window.end)")
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

                if !viewModel.hourlyItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.l("planner.hourly"))
                            .font(.headline)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        ForEach(viewModel.hourlyItems, id: \.hour) { item in
                            HStack {
                                Text(item.hour)
                                Spacer()
                                Text(item.overallRisk.uppercased())
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.white.opacity(0.1), in: Capsule())
                            }
                            .font(.subheadline)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
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
}
