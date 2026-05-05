import SwiftUI

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published var loading = false
    @Published var statusText = "-"
    @Published var items: [PersonalPatternInsight] = []
    @Published var lastError: String? = nil

    private let apiClient = APIClient.live()

    func refresh(profileId: String, userId: String, accessToken: String, language: String) async {
        loading = true
        defer { loading = false }
        do {
            let response = try await apiClient.fetchPersonalPatterns(
                profileId: profileId,
                userId: userId,
                accessToken: accessToken,
                windowDays: 30,
                language: language
            )
            items = response.items
            lastError = nil
            statusText = response.items.isEmpty
                ? HiAirL10n.t("insights.unlock_more", lang: language)
                : "\(response.items.count) \(HiAirL10n.t("insights.count", lang: language))"
        } catch {
            items = []
            let message = HiAirL10n.t("insights.failed", lang: language)
            statusText = message
            lastError = message
        }
    }
}

struct InsightsView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = InsightsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(session.l("common.city_updated"))
                    .font(AuroraTokens.Typography.caption)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
                Text(session.l("tab.insights"))
                    .font(AuroraTokens.Typography.displayLG)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                Text(viewModel.statusText)
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                if session.profileId.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.l("planner.empty.no_profile.title"))
                            .font(AuroraTokens.Typography.titleMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        Text(session.l("planner.empty.no_profile.body"))
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                        Button(session.l("planner.empty.no_profile.cta")) {
                            Task {
                                let created = await session.ensureProfileIdIfNeeded()
                                if created {
                                    session.markChecklistItem("profile", done: true)
                                    await viewModel.refresh(
                                        profileId: session.profileId,
                                        userId: session.userId,
                                        accessToken: session.accessToken,
                                        language: session.preferredLanguage
                                    )
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(HiAirV2Theme.accentStart)
                    }
                    .v2Card()
                }

                if viewModel.loading {
                    Text(session.l("insights.loading"))
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        .v2Card()
                } else if let lastError = viewModel.lastError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lastError)
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(AuroraTokens.ColorPalette.errorSoft.opacity(0.9))
                        Button(session.l("insights.retry")) {
                            Task {
                                await viewModel.refresh(
                                    profileId: session.profileId,
                                    userId: session.userId,
                                    accessToken: session.accessToken,
                                    language: session.preferredLanguage
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    .v2Card()
                } else if viewModel.items.isEmpty {
                    Text(session.l("insights.empty"))
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        .v2Card()
                } else {
                    ForEach(Array(viewModel.items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(item.factorA) ↔ \(item.factorB)")
                                .font(AuroraTokens.Typography.titleMD)
                                .foregroundStyle(HiAirV2Theme.primaryText)
                            Text(item.humanReadableText)
                                .font(AuroraTokens.Typography.bodyMD)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Text("r=\(item.coefficient, specifier: "%.2f"), p=\(item.pValue, specifier: "%.3f"), n=\(item.sampleSize)")
                                .font(AuroraTokens.Typography.caption)
                                .foregroundStyle(HiAirV2Theme.tertiaryText)
                        }
                        .v2Card()
                    }
                }

                Button(viewModel.loading ? session.l("dashboard.loading") : session.l("planner.refresh")) {
                    Task {
                        if session.profileId.isEmpty {
                            _ = await session.ensureProfileIdIfNeeded()
                        }
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
                        session.markChecklistItem("recommendations", done: true)
                    }
                }
                .buttonStyle(V2PrimaryButtonStyle())
                .disabled(viewModel.loading)
            }
            .padding(16)
        }
        .v2PageBackground()
        .task {
            if session.profileId.isEmpty {
                _ = await session.ensureProfileIdIfNeeded()
            }
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
            session.markChecklistItem("recommendations", done: true)
        }
    }
}
