import SwiftUI

@MainActor
final class InsightsViewModel: ObservableObject {
    static let targetLogDays = 7

    @Published var loading = false
    @Published var statusText = "-"
    @Published var items: [PersonalPatternInsight] = []
    @Published var trends: [HealthInsightCardDTO] = []
    @Published var associations: [HealthInsightCardDTO] = []
    @Published var insufficient: [InsufficientDataCardDTO] = []
    @Published var todaySummary: String = "—"
    @Published var healthStatusText: String = "—"
    @Published var lastError: String? = nil
    @Published var loggedDays = 0
    @Published var generatedAtDisplay = "—"

    private let apiClient = APIClient.live()

    var progressFraction: Double {
        Double(min(loggedDays, Self.targetLogDays)) / Double(Self.targetLogDays)
    }

    func refresh(
        profileId: String,
        userId: String,
        accessToken: String,
        language: String,
        onPremiumRequired: (() -> Void)? = nil
    ) async {
        loading = true
        defer { loading = false }
        do {
            async let historyTask = apiClient.fetchSymptomHistory(
                profileId: profileId,
                userId: userId,
                accessToken: accessToken
            )
            let history: SymptomHistoryResponse
            do {
                history = try await historyTask
            } catch {
                history = SymptomHistoryResponse(profileId: profileId, items: [])
            }
            loggedDays = uniqueLogDays(from: history.items)

            do {
                let bundle = try await apiClient.fetchHealthInsightsBundle(
                    profileId: profileId,
                    userId: userId,
                    accessToken: accessToken,
                    windowDays: 30,
                    language: language
                )
                trends = bundle.trends
                associations = bundle.associations
                insufficient = bundle.insufficientData
                if loggedDays == 0, let have = bundle.insufficientData.first?.have {
                    loggedDays = have
                }
                generatedAtDisplay = HiAirHumanDate.display(
                    fromISO: bundle.generatedAt,
                    locale: Locale(identifier: language),
                    style: .dateTime
                )
                todaySummary = formatToday(bundle.today, language: language)
                if let status = bundle.healthDataStatus {
                    let sync = status.syncStatus ?? "—"
                    let metrics = status.metricDays ?? 0
                    healthStatusText = String(
                        format: HiAirL10n.t("insights.health_status", lang: language),
                        locale: Locale(identifier: language),
                        metrics,
                        sync
                    )
                } else {
                    healthStatusText = HiAirL10n.t("insights.health_status_unknown", lang: language)
                }
            } catch let error as APIError {
                trends = []
                associations = []
                insufficient = []
                if case .server(let code) = error, code == 402 {
                    onPremiumRequired?()
                }
            } catch {
                trends = []
                associations = []
                insufficient = []
            }

            // Legacy personal patterns remain available for Premium users.
            do {
                let patterns = try await apiClient.fetchPersonalPatterns(
                    profileId: profileId,
                    userId: userId,
                    accessToken: accessToken,
                    windowDays: 30,
                    language: language
                )
                items = patterns.items
            } catch {
                items = []
            }

            lastError = nil
            let totalCards = trends.count + associations.count + items.count
            statusText = totalCards == 0
                ? HiAirL10n.t("state.empty.insights.body", lang: language)
                : "\(totalCards) \(HiAirL10n.t("insights.count", lang: language))"
        } catch {
            trends = []
            associations = []
            insufficient = []
            items = []
            let message = HiAirL10n.t("insights.failed", lang: language)
            statusText = message
            lastError = message
        }
    }

    private func uniqueLogDays(from items: [SymptomHistoryItem]) -> Int {
        let calendar = Calendar.current
        var days = Set<DateComponents>()
        for item in items {
            guard let date = HiAirHumanDate.date(fromISO: item.loggedAt) else { continue }
            days.insert(calendar.dateComponents([.year, .month, .day], from: date))
        }
        return days.count
    }

    private func formatToday(_ today: [String: AnyCodableValue]?, language: String) -> String {
        guard let today else { return "—" }
        var parts: [String] = []
        if case .double(let steps) = today["steps"] {
            parts.append(String(format: HiAirL10n.t("insights.today.steps", lang: language), Int(steps)))
        } else if case .int(let steps) = today["steps"] {
            parts.append(String(format: HiAirL10n.t("insights.today.steps", lang: language), steps))
        }
        if case .double(let sleep) = today["sleepMinutes"] {
            parts.append(String(format: HiAirL10n.t("insights.today.sleep", lang: language), Int(sleep)))
        } else if case .int(let sleep) = today["sleepMinutes"] {
            parts.append(String(format: HiAirL10n.t("insights.today.sleep", lang: language), sleep))
        }
        if case .double(let rhr) = today["restingHeartRate"] {
            parts.append(String(format: HiAirL10n.t("insights.today.rhr", lang: language), Int(rhr)))
        }
        return parts.isEmpty ? HiAirL10n.t("insights.today.empty", lang: language) : parts.joined(separator: " · ")
    }
}

struct InsightsView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = InsightsViewModel()

    var body: some View {
        HiAirAdaptiveLayout { width, mode in
            ScrollView {
                VStack(alignment: .leading, spacing: HiAirResponsiveSpacing.sectionSpacing(for: mode)) {
                    Text(session.l("tab.insights"))
                        .font(AuroraTokens.Typography.displayLG)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                        .accessibilityAddTraits(.isHeader)

                    if session.profileId.isEmpty {
                        HiAirEmptyStateView(
                            title: session.l("planner.empty.no_profile.title"),
                            message: session.l("planner.empty.no_profile.body"),
                            actionTitle: session.l("planner.empty.no_profile.cta"),
                            action: {
                                Task {
                                    let created = await session.ensureProfileIdIfNeeded()
                                    if created {
                                        session.markChecklistItem("profile", done: true)
                                        await refreshInsights()
                                    }
                                }
                            }
                        )
                        .v2Card()
                    } else if viewModel.loading {
                        HiAirLoadingView(message: session.l("insights.loading"))
                            .v2Card()
                    } else if let lastError = viewModel.lastError {
                        HiAirErrorView(
                            title: session.l("common.error.title"),
                            message: lastError,
                            retryTitle: session.l("insights.retry"),
                            onRetry: { Task { await refreshInsights() } }
                        )
                        .v2Card()
                    } else {
                        todayCard
                        progressCard
                        trendsSection
                        associationsSection
                        insufficientSection
                        healthStatusCard
                        if !viewModel.items.isEmpty {
                            premiumPatternsSection
                        }
                        checklistCard
                    }

                    Button(viewModel.loading ? session.l("insights.loading") : session.l("insights.refresh")) {
                        Task {
                            if session.profileId.isEmpty {
                                _ = await session.ensureProfileIdIfNeeded()
                            }
                            guard !session.profileId.isEmpty else { return }
                            await refreshInsights()
                            session.markChecklistItem("recommendations", done: true)
                        }
                    }
                    .buttonStyle(HiAirGradientButtonStyle())
                    .disabled(viewModel.loading)
                }
                .hiAirContentWidth(for: width)
                .hiAirScreenPadding(for: width)
                .padding(.bottom, HiAirSpacing.xl)
            }
        }
        .hiAirPageBackground()
        .task {
            if session.profileId.isEmpty {
                _ = await session.ensureProfileIdIfNeeded()
            }
            guard !session.profileId.isEmpty else { return }
            await refreshInsights()
            session.markChecklistItem("recommendations", done: true)
        }
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.l("insights.section.today"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            Text(viewModel.todaySummary)
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            if viewModel.generatedAtDisplay != "—" {
                Text(viewModel.generatedAtDisplay)
                    .font(AuroraTokens.Typography.caption)
                    .foregroundStyle(HiAirV2Theme.tertiaryText)
            }
        }
        .v2Card()
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l("insights.section.trends"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            if viewModel.trends.isEmpty {
                Text(session.l("insights.section.trends.empty"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
            } else {
                ForEach(viewModel.trends) { card in
                    insightCard(card)
                }
            }
        }
    }

    private var associationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l("insights.section.associations"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            if viewModel.associations.isEmpty {
                Text(session.l("insights.section.associations.empty"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
            } else {
                ForEach(viewModel.associations) { card in
                    insightCard(card)
                }
            }
        }
    }

    private var insufficientSection: some View {
        Group {
            if !viewModel.insufficient.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("insights.section.insufficient"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    ForEach(viewModel.insufficient) { card in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(card.message)
                                .font(AuroraTokens.Typography.bodyMD)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            if let have = card.have, let need = card.need {
                                Text("\(have)/\(need)")
                                    .font(AuroraTokens.Typography.caption)
                                    .foregroundStyle(HiAirV2Theme.tertiaryText)
                            }
                        }
                        .v2Card()
                    }
                }
            }
        }
    }

    private var healthStatusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.l("insights.section.health_status"))
                .font(AuroraTokens.Typography.titleMD)
            Text(viewModel.healthStatusText)
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
        }
        .v2Card()
    }

    private var premiumPatternsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l("insights.section.premium_patterns"))
                .font(AuroraTokens.Typography.titleMD)
            ForEach(Array(viewModel.items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(item.factorA) ↔ \(item.factorB)")
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Text(item.humanReadableText)
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                }
                .v2Card()
            }
        }
    }

    private func insightCard(_ card: HealthInsightCardDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title)
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            Text(card.observation)
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            if let recommendation = card.recommendation, !recommendation.isEmpty {
                Text(recommendation)
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
            }
            Text(confidenceLabel(card.confidence))
                .font(AuroraTokens.Typography.caption)
                .foregroundStyle(HiAirV2Theme.tertiaryText)
            if let why = card.whyShown {
                Text(why)
                    .font(AuroraTokens.Typography.caption)
                    .foregroundStyle(HiAirV2Theme.tertiaryText)
            }
            if let limitations = card.limitations {
                ForEach(limitations, id: \.self) { line in
                    Text(line)
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.tertiaryText)
                }
            }
        }
        .v2Card()
        .accessibilityElement(children: .combine)
    }

    private func confidenceLabel(_ value: String) -> String {
        switch value {
        case "preliminary": return session.l("insights.confidence.preliminary")
        case "moderate": return session.l("insights.confidence.moderate")
        case "stronger": return session.l("insights.confidence.stronger")
        case "insufficient": return session.l("insights.confidence.insufficient")
        default: return value
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.md) {
            Text(session.l("insights.progress_title"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            Text(
                String(
                    format: session.l("insights.progress_days"),
                    locale: Locale(identifier: session.preferredLanguage),
                    viewModel.loggedDays,
                    InsightsViewModel.targetLogDays
                )
            )
            .font(AuroraTokens.Typography.bodyMD)
            .foregroundStyle(HiAirV2Theme.primaryText)
            ProgressView(value: viewModel.progressFraction)
                .tint(HiAirV2Theme.accentStart)
            Text(viewModel.statusText)
                .font(AuroraTokens.Typography.caption)
                .foregroundStyle(HiAirV2Theme.secondaryText)
        }
        .v2Card()
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            Text(session.l("insights.next_step"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            Button(session.l("insights.next.log_symptoms")) {
                session.selectedTab = 3
            }
            .buttonStyle(HiAirSecondaryButtonStyle())
            .frame(minHeight: 44)
            Button(session.l("insights.next.open_planner")) {
                session.selectedTab = 1
            }
            .buttonStyle(HiAirSecondaryButtonStyle())
            .frame(minHeight: 44)
        }
        .v2Card()
    }

    private func refreshInsights() async {
        await viewModel.refresh(
            profileId: session.profileId,
            userId: session.userId,
            accessToken: session.accessToken,
            language: session.preferredLanguage,
            onPremiumRequired: { session.showPaywall = true }
        )
    }
}
