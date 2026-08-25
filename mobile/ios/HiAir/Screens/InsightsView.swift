import Charts
import SwiftUI

@MainActor
final class InsightsViewModel: ObservableObject {
    static let targetLogDays = 7

    @Published var loading = false
    @Published var statusText = ""
    @Published var items: [PersonalPatternInsight] = []
    @Published var trends: [HealthInsightCardDTO] = []
    @Published var associations: [HealthInsightCardDTO] = []
    @Published var insufficient: [InsufficientDataCardDTO] = []
    @Published var todaySummary: String = ""
    @Published var healthStatusText: String = ""
    @Published var lastError: String? = nil
    @Published var loggedDays = 0
    @Published var generatedAtDisplay = ""
    @Published var premiumLocked = false
    @Published var adaptation: PersonalAdaptationSnapshot?
    @Published var windowDays: Int = 30

    private let apiClient = APIClient.live()

    var progressFraction: Double {
        Double(min(loggedDays, Self.targetLogDays)) / Double(Self.targetLogDays)
    }

    func refresh(
        profileId: String,
        userId: String,
        accessToken: String,
        language: String,
        windowDays: Int? = nil,
        onPremiumRequired: (() -> Void)? = nil
    ) async {
        if let windowDays {
            self.windowDays = windowDays
        }
        loading = true
        defer { loading = false }
        premiumLocked = false
        adaptation = nil
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
                    windowDays: self.windowDays,
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
                    let syncKey: String
                    switch (status.syncStatus ?? "").lowercased() {
                    case "ok", "success", "synced":
                        syncKey = "insights.sync.ok"
                    case "partial":
                        syncKey = "insights.sync.partial"
                    case "pending", "syncing":
                        syncKey = "insights.sync.pending"
                    case "error", "failed":
                        syncKey = "insights.sync.error"
                    default:
                        syncKey = "insights.sync.unknown"
                    }
                    let metrics = status.metricDays ?? 0
                    healthStatusText = String(
                        format: HiAirL10n.t("insights.health_status", lang: language),
                        locale: Locale(identifier: language),
                        metrics,
                        HiAirL10n.t(syncKey, lang: language)
                    )
                } else {
                    healthStatusText = HiAirL10n.t("insights.health_status_unknown", lang: language)
                }
            } catch let error as APIError {
                trends = []
                associations = []
                insufficient = []
                if case .server(let code) = error, code == 402 {
                    premiumLocked = true
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
                    windowDays: self.windowDays,
                    language: language
                )
                items = patterns.items
            } catch let error as APIError {
                items = []
                if case .server(let code) = error, code == 402 {
                    premiumLocked = true
                    onPremiumRequired?()
                }
            } catch {
                items = []
            }

            do {
                adaptation = try await apiClient.fetchAdaptation(
                    profileId: profileId,
                    userId: userId,
                    accessToken: accessToken
                )
            } catch let error as APIError {
                adaptation = nil
                if case .server(let code) = error, code == 402 {
                    premiumLocked = true
                    onPremiumRequired?()
                }
            } catch {
                adaptation = nil
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
        guard let today else { return HiAirL10n.t("insights.today.empty", lang: language) }
        var parts: [String] = []
        if let steps = intValue(today["steps"]) {
            parts.append(String(format: HiAirL10n.t("insights.today.steps", lang: language), steps))
        }
        if let sleep = intValue(today["sleepMinutes"]) {
            parts.append(String(format: HiAirL10n.t("insights.today.sleep", lang: language), sleep))
        }
        if let rhr = intValue(today["restingHeartRate"]) {
            parts.append(String(format: HiAirL10n.t("insights.today.rhr", lang: language), rhr))
        }
        if let hrv = intValue(today["hrv"]) {
            parts.append(String(format: HiAirL10n.t("insights.today.hrv", lang: language), hrv))
        }
        if let spo2 = intValue(today["oxygenSaturation"] ?? today["spo2"]) {
            parts.append(String(format: HiAirL10n.t("insights.today.spo2", lang: language), spo2))
        }
        if let resp = intValue(today["respiratoryRate"]) {
            parts.append(String(format: HiAirL10n.t("insights.today.resp", lang: language), resp))
        }
        if let distance = intValue(today["distanceMeters"]) {
            let km = Double(distance) / 1000.0
            parts.append(String(format: HiAirL10n.t("insights.today.distance", lang: language), km))
        }
        if let energy = intValue(today["activeEnergyKcal"]) {
            parts.append(String(format: HiAirL10n.t("insights.today.energy", lang: language), energy))
        }
        if let vo2 = intValue(today["vo2Max"]) {
            parts.append(String(format: HiAirL10n.t("insights.today.vo2", lang: language), vo2))
        }
        if let workouts = intValue(today["workoutCount"]), workouts > 0 {
            parts.append(String(format: HiAirL10n.t("insights.today.workouts", lang: language), workouts))
        }
        return parts.isEmpty ? HiAirL10n.t("insights.today.empty", lang: language) : parts.joined(separator: " · ")
    }

    private func intValue(_ value: AnyCodableValue?) -> Int? {
        switch value {
        case .int(let v): return v
        case .double(let v): return Int(v.rounded())
        default: return nil
        }
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
                        ProfileBootstrapCard(
                            titleKey: "planner.empty.no_profile.title",
                            bodyKey: "planner.empty.no_profile.body",
                            ctaKey: "planner.empty.no_profile.cta",
                            ctaAccessibilityID: HiAirAccessibilityID.Insights.createProfileCTA,
                            onReady: { await refreshInsights() }
                        )
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
                        windowPicker
                        todayCard
                        adaptationCard
                        if viewModel.premiumLocked {
                            premiumLockedCard
                        }
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
                                // Explicit user refresh — do not reuse a prior terminal ensure failure.
                                session.beginExplicitProfileEnsureCycle()
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
            if UITestBootstrap.disableAutoProfileBootstrap {
                return
            }
            if session.profileId.isEmpty {
                _ = await session.ensureProfileIdIfNeeded()
            }
            guard !session.profileId.isEmpty else { return }
            await refreshInsights()
            session.markChecklistItem("recommendations", done: true)
        }
    }

    private var windowPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HiAirSectionHeader(title: session.l("insights.window.title"))
            HStack(spacing: 8) {
                windowChip(days: 7, title: session.l("insights.window.7d"))
                windowChip(days: 30, title: session.l("insights.window.30d"))
            }
            Text(session.l("insights.window.hint"))
                .font(HiAirTypography.caption)
                .foregroundStyle(HiAirColors.Text.tertiary)
        }
        .v2Card()
    }

    private func windowChip(days: Int, title: String) -> some View {
        let selected = viewModel.windowDays == days
        return Button {
            Task {
                await viewModel.refresh(
                    profileId: session.profileId,
                    userId: session.userId,
                    accessToken: session.accessToken,
                    language: session.preferredLanguage,
                    windowDays: days,
                    onPremiumRequired: { session.showPaywall = true }
                )
            }
        } label: {
            Text(title)
                .font(AuroraTokens.Typography.bodyMD)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? HiAirV2Theme.accentStart.opacity(0.22) : HiAirV2Theme.cardFill)
                .foregroundStyle(HiAirV2Theme.primaryText)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.l("insights.section.today"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            Text(viewModel.todaySummary.isEmpty ? session.l("insights.today.empty") : viewModel.todaySummary)
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            if !viewModel.generatedAtDisplay.isEmpty {
                Text(viewModel.generatedAtDisplay)
                    .font(AuroraTokens.Typography.caption)
                    .foregroundStyle(HiAirV2Theme.tertiaryText)
            }
        }
        .v2Card()
    }

    @ViewBuilder
    private var adaptationCard: some View {
        if let snapshot = viewModel.adaptation {
            VStack(alignment: .leading, spacing: 10) {
                Text(session.l("insights.adaptation.title"))
                    .font(AuroraTokens.Typography.titleMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                let availableBaselines = snapshot.baselines.filter(\.available)
                if availableBaselines.isEmpty {
                    Text(session.l("insights.adaptation.baselines.empty"))
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                } else {
                    ForEach(availableBaselines) { baseline in
                        Text(adaptationBaselineLine(baseline))
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                    }
                }
                if snapshot.protectedDays.available {
                    Text(adaptationProtectedDaysLine(snapshot.protectedDays))
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                } else {
                    Text(session.l("insights.adaptation.protected.empty"))
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                }
                if snapshot.reasonCodes.contains("association_not_causation") {
                    Text(session.l("insights.adaptation.association_not_causation"))
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.tertiaryText)
                }
            }
            .v2Card()
        }
    }

    private func adaptationBaselineLine(_ baseline: PersonalBaseline) -> String {
        let metric = session.l("insights.adaptation.metric.\(baseline.metric)")
        let window = session.l("insights.adaptation.window.\(baseline.window)")
        guard let value = baseline.value else {
            return "\(metric) (\(window)): \(session.l("dashboard.hazards.unavailable"))"
        }
        return String(
            format: session.l("insights.adaptation.baseline_line"),
            locale: Locale(identifier: session.preferredLanguage),
            metric,
            window,
            value
        )
    }

    private func adaptationProtectedDaysLine(_ summary: ProtectedDaysSummary) -> String {
        String(
            format: session.l("insights.adaptation.protected_days"),
            locale: Locale(identifier: session.preferredLanguage),
            summary.highRiskPeriodsAvoided,
            summary.workoutsMoved,
            summary.ventilationWindowsUsed,
            summary.poorAirExposureReduced
        )
    }

    private var premiumLockedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l("insights.premium_locked.title"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            Text(session.l("insights.premium_locked.body"))
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            Button(session.l("insights.premium_locked.cta")) {
                session.showPaywall = true
            }
            .buttonStyle(HiAirGradientButtonStyle())
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
                                Text(String(format: session.l("insights.progress_days"), have, need))
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
                    Text(item.humanReadableText)
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                }
                .v2Card()
            }
        }
    }

    private func insightCard(_ card: HealthInsightCardDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title)
                .font(HiAirTypography.titleMD)
                .foregroundStyle(HiAirColors.Text.primary)
            Text(card.observation)
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.secondary)
            if let points = card.chart?.points, points.count >= 2 {
                Chart(points) { point in
                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(HiAirColors.Brand.orbCyan.gradient)
                    AreaMark(
                        x: .value("Day", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(HiAirColors.Brand.orbCyan.opacity(0.12))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 72)
                .accessibilityHidden(true)
            }
            if let recommendation = card.recommendation, !recommendation.isEmpty {
                Text(recommendation)
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirColors.Text.primary)
            }
            Text(confidenceLabel(card.confidence))
                .font(HiAirTypography.caption)
                .foregroundStyle(HiAirColors.Text.tertiary)
            if let why = card.whyShown {
                Text(why)
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirColors.Text.tertiary)
            }
            if let limitations = card.limitations {
                ForEach(limitations, id: \.self) { line in
                    Text(line)
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirColors.Text.tertiary)
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
        default: return session.l("insights.confidence.preliminary")
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
