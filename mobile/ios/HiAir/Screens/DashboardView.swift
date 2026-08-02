import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var loading = false
    @Published var hasLoadedOnce = false
    @Published var riskLevel = ""
    @Published var explanation = ""
    @Published var headline = ""
    @Published var actions: [String] = []
    @Published var nearestSafeWindow = ""
    @Published var safeWindowLabels: [String] = []
    @Published var environmental: AirEnvironmentalInput?
    @Published var wearableToday: WearableTodayResponse?
    @Published var healthSummary: HealthSummaryResponseDTO?
    @Published var morningReport: AIReportResponseDTO?
    @Published var wearableConnectionState: WearableConnectionState = .notConnected
    @Published var loadFailed = false

    private let apiClient = APIClient.live()
    private let healthService = HealthKitService.shared

    func refresh(
        userId: String,
        accessToken: String,
        profileId: String?,
        language: String
    ) async {
        loading = true
        loadFailed = false
        defer {
            loading = false
            hasLoadedOnce = true
        }
        guard let profileId, !profileId.isEmpty else {
            riskLevel = "unknown"
            headline = HiAirL10n.t("dashboard.empty.no_profile.title", lang: language)
            explanation = HiAirL10n.t("dashboard.empty.no_profile.body", lang: language)
            actions = []
            nearestSafeWindow = ""
            safeWindowLabels = []
            environmental = nil
            wearableToday = nil
            healthSummary = nil
            morningReport = nil
            return
        }
        do {
            async let riskTask = apiClient.fetchCurrentRisk(
                profileId: profileId,
                userId: userId,
                accessToken: accessToken
            )
            async let wearableTask = apiClient.fetchWearableToday(userId: userId, accessToken: accessToken)
            async let summaryTask = apiClient.fetchHealthSummary(userId: userId, accessToken: accessToken)
            async let morningTask = apiClient.fetchAIReport(
                kind: "morning",
                profileId: profileId,
                userId: userId,
                accessToken: accessToken
            )
            let result = try await riskTask
            wearableToday = try? await wearableTask
            healthSummary = try? await summaryTask
            morningReport = try? await morningTask
            // Prefer live connectionState over sync-gated refresh (Connected ≠ full sync done).
            let live = healthService.connectionState
            switch live {
            case .connected, .permissionRequested, .systemAuthorized, .consentSaving, .consentFailed,
                 .revoking, .remoteRevokePending, .revokeFailed:
                wearableConnectionState = live
            default:
                wearableConnectionState = healthService.refreshAuthorizationState()
            }
            riskLevel = result.risk.overallRisk
            explanation = result.explanation
            headline = result.recommendation.headline
            actions = result.recommendation.actions
            environmental = result.environmental
            let locale = Locale(identifier: language)
            safeWindowLabels = result.risk.safeWindows.map { window in
                Self.formatSafeWindow(type: window.type, start: window.start, end: window.end, language: language, locale: locale)
            }
            if let firstWindow = result.risk.safeWindows.first {
                nearestSafeWindow = Self.formatSafeWindow(
                    type: firstWindow.type,
                    start: firstWindow.start,
                    end: firstWindow.end,
                    language: language,
                    locale: locale
                )
            } else {
                nearestSafeWindow = HiAirL10n.t("dashboard.no_safe_window", lang: language)
            }
        } catch {
            loadFailed = true
            riskLevel = "error"
            headline = HiAirL10n.t("dashboard.error", lang: language)
            explanation = HiAirL10n.t("dashboard.empty.api_unavailable", lang: language)
            actions = []
            nearestSafeWindow = ""
            safeWindowLabels = []
            environmental = nil
            healthSummary = nil
            morningReport = nil
        }
    }

    private static func formatSafeWindow(
        type: String,
        start: String,
        end: String,
        language: String,
        locale: Locale
    ) -> String {
        let typeKey: String
        switch type.lowercased() {
        case "walk", "outdoor", "safe":
            typeKey = "planner.window.safe"
        case "ventilation", "ventilate":
            typeKey = "planner.window.ventilation"
        case "sport", "exercise", "run":
            typeKey = "planner.window.safe"
        default:
            typeKey = "dashboard.safe_window"
        }
        let label = HiAirL10n.t(typeKey, lang: language)
        let range = HiAirHumanDate.timeRange(fromISO: start, toISO: end, locale: locale, unavailable: "")
        if range.isEmpty {
            return label
        }
        return "\(label): \(range)"
    }
}

struct DashboardView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var healthService = HealthKitService.shared
    @StateObject private var locationService = LocationService.shared
    @State private var activeInfoKey: InfoTerm?
    @State private var showWearableConsent = false

    private var riskScore: Int? {
        // Keep in sync with backend RISK_LEVEL_TO_SCORE (air_score.py).
        switch viewModel.riskLevel.lowercased() {
        case "low":
            return 20
        case "moderate", "medium":
            return 45
        case "high":
            return 70
        case "very_high", "very high":
            return 90
        default:
            return nil
        }
    }

    private var riskColor: Color {
        RiskAccentColor.color(for: viewModel.riskLevel.isEmpty ? "moderate" : viewModel.riskLevel)
    }

    private var moodTitle: String {
        switch viewModel.riskLevel.lowercased() {
        case "low":
            return session.l("dashboard.mood.calm")
        case "moderate", "medium":
            return session.l("dashboard.mood.aware")
        case "high":
            return session.l("dashboard.mood.cautious")
        case "very_high", "very high":
            return session.l("dashboard.mood.protective")
        default:
            return session.l("dashboard.mood.calm")
        }
    }

    private var pm25ForAtmosphere: Double? {
        viewModel.environmental?.pm25
    }

    private var freshnessLabel: String {
        viewModel.loading ? session.l("dashboard.freshness_updating") : session.l("dashboard.freshness_fresh")
    }

    private var showLiveRiskContent: Bool {
        viewModel.hasLoadedOnce && !viewModel.riskLevel.isEmpty && viewModel.riskLevel != "unknown" && !viewModel.loadFailed
    }

    private var safeWindows: [String] {
        viewModel.safeWindowLabels
    }

    private var locationLabel: String {
        if let place = session.displayPlaceName, !place.isEmpty {
            return place
        }
        if session.hasValidLocation {
            // Coords known but geocode pending/failed — keep short area fallback.
            return session.l("dashboard.location")
        }
        return session.l("dashboard.location_unknown")
    }

    private func reloadDashboard(skipProfileEnsure: Bool = false) async {
        // Cold launch: `prepareSessionForDataFetch` already ran ensure — do not fire a second request.
        if !skipProfileEnsure,
           session.profileId.isEmpty,
           !UITestBootstrap.disableAutoProfileBootstrap {
            _ = await session.ensureProfileIdIfNeeded()
        }
        // Never block dashboard/geo refresh on HealthKit sync.
        // Sync only via cancellable coordinator after durable consent.
        if !session.userId.isEmpty {
            healthService.startBackgroundHealthSync(
                userId: session.userId,
                accessToken: session.accessToken,
                profileId: session.profileId.isEmpty ? nil : session.profileId
            )
        }
        await viewModel.refresh(
            userId: session.userId,
            accessToken: session.accessToken,
            profileId: session.profileId.isEmpty ? nil : session.profileId,
            language: session.preferredLanguage
        )
    }

    private var riskReason: String {
        let morning = viewModel.morningReport?.narrative.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !morning.isEmpty {
            return morning
        }
        let explanation = viewModel.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explanation.isEmpty, explanation != "-" {
            return explanation
        }
        return session.l("dashboard.reason_unavailable")
    }

    private var weatherTitle: String {
        if let env = viewModel.environmental {
            return String(format: "%.0f°C", env.temperature)
        }
        return session.l("dashboard.weather_unavailable")
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

    private var todayHumanDate: String {
        HiAirHumanDate.string(
            from: Date(),
            locale: Locale(identifier: session.preferredLanguage),
            style: .dateMedium
        )
    }

    private var showStarterChecklist: Bool {
        guard !session.checklistHidden else { return false }
        return starterChecklist.contains { !session.isChecklistItemDone($0.id) }
    }

    var body: some View {
        HiAirAdaptiveLayout { width, mode in
            ScrollView {
                VStack(alignment: .leading, spacing: HiAirResponsiveSpacing.sectionSpacing(for: mode)) {
                    dashboardHeader
                    greetingSection
                    emptyStateSections

                    if viewModel.loading && !viewModel.hasLoadedOnce {
                        HiAirSkeletonStack(cards: 4)
                    } else if viewModel.loadFailed {
                        HiAirErrorView(
                            title: session.l("dashboard.error"),
                            message: session.l("dashboard.empty.api_unavailable"),
                            retryTitle: session.l("common.retry"),
                            onRetry: {
                                Task {
                                    session.beginExplicitProfileEnsureCycle()
                                    await reloadDashboard()
                                }
                            }
                        )
                        .v2Card()
                    } else if showLiveRiskContent {
                        aiSummarySection
                        riskHeroSection(width: width)
                        todaysAirSection
                        healthMetricsSection
                        wearableLoadSection
                        quickActionsSection
                        safeWindowsSection
                    }

                    if showStarterChecklist {
                        checklistSection
                    }
                }
                .hiAirContentWidth(for: width)
                .hiAirScreenPadding(for: width)
                .padding(.bottom, HiAirSpacing.xl)
            }
            .refreshable {
                session.beginExplicitProfileEnsureCycle()
                await reloadDashboard()
            }
        }
        .hiAirPageBackground()
        .overlay {
            if let pm25 = pm25ForAtmosphere {
                AtmosphericParticles(pm25: pm25, tint: riskColor)
                    .allowsHitTesting(false)
            }
        }
        .task {
            ProductAnalytics.track("dashboard_opened")
            StartupDiagnostics.track(
                "dashboard_refresh_started",
                profilePresent: !session.profileId.isEmpty
            )
            // Never block first paint on location when profile already exists.
            let hadProfile = !session.profileId.isEmpty
            if hadProfile {
                await reloadDashboard()
            }
            if UITestBootstrap.disableAutoProfileBootstrap {
                if !hadProfile {
                    await reloadDashboard()
                }
            } else {
                _ = await session.prepareSessionForDataFetch(locationService: locationService)
                // Always refresh dashboard data once; skip ensure — prepare already single-flighted it.
                await reloadDashboard(skipProfileEnsure: true)
            }
            session.markChecklistItem("risk", done: true)
            StartupDiagnostics.track(
                "dashboard_refresh_succeeded",
                success: !viewModel.loadFailed,
                profilePresent: !session.profileId.isEmpty
            )
        }
        .onChange(of: session.locationRevision) { _ in
            // Independent coordinate change — ensure still required when profile is empty.
            Task { await reloadDashboard() }
        }
        .onChange(of: session.displayPlaceName) { _ in
            // Place chip updates without full dashboard reload.
        }
        .onChange(of: healthService.connectionState) { newState in
            viewModel.wearableConnectionState = newState
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileLocationDidUpdate)) { notification in
            // Re-evaluate skip inside the Task so a stale post after account switch cannot
            // suppress ensure for the newly signed-in user.
            Task {
                let skipEnsure = ProfileLocationUpdateContext.skipProfileEnsure(
                    from: notification,
                    currentUserId: session.userId
                )
                await reloadDashboard(skipProfileEnsure: skipEnsure)
            }
        }
        .sheet(item: $activeInfoKey) { item in
            InfoTextSheet(text: session.l(item.id), closeTitle: session.l("common.close"))
        }
        .sheet(isPresented: $showWearableConsent) {
            WearableConsentView(fromOnboarding: false) {
                Task {
                    await viewModel.refresh(
                        userId: session.userId,
                        accessToken: session.accessToken,
                        profileId: session.profileId.isEmpty ? nil : session.profileId,
                        language: session.preferredLanguage
                    )
                }
            }
            .environmentObject(session)
        }
    }

    @ViewBuilder
    private var healthMetricsSection: some View {
        if viewModel.wearableConnectionState == .connected {
            HealthTodayMetricsView(
                summary: viewModel.healthSummary,
                personalLoad: viewModel.wearableToday?.personalLoad
            )
        }
    }

    @ViewBuilder
    private var wearableLoadSection: some View {
        WearableLoadCardView(
            today: viewModel.wearableToday,
            connectionState: viewModel.wearableConnectionState,
            onConnect: { showWearableConsent = true },
            onOpenSettings: {
                HealthKitService.openHealthApp()
            }
        )
    }

    @ViewBuilder
    private var dashboardHeader: some View {
        HStack(spacing: HiAirSpacing.xs) {
            Button {
                Task {
                    if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
                        locationService.openAppSettings()
                    } else {
                        _ = await session.bootstrapLocationFromDevice(locationService: locationService)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                    Text(locationLabel)
                }
                .font(HiAirTypography.caption)
                .foregroundStyle(HiAirV2Theme.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .hiAirChipSurface()
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(viewModel.loading ? HiAirColors.Risk.moderate : HiAirColors.Risk.low)
                    .frame(width: 6, height: 6)
                Text(freshnessLabel)
                    .font(HiAirTypography.caption)
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
    }

    @ViewBuilder
    private var greetingSection: some View {
        HiAirBrandHeader(
            title: "HiAir",
            subtitle: nil,
            showOrb: true,
            orbSize: 44,
            compact: true
        )
        Text(todayHumanDate)
            .font(HiAirTypography.caption)
            .foregroundStyle(HiAirColors.Text.tertiary)

        let greeting = viewModel.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        Text(greeting.isEmpty || greeting == "-" ? session.l("dashboard.greeting_neutral") : greeting)
            .font(HiAirTypography.displayLG)
            .foregroundStyle(HiAirColors.Text.primary)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var aiSummarySection: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            HiAirSectionHeader(title: session.l("dashboard.section.ai_summary"))
            Text(riskReason)
                .font(HiAirTypography.bodyLG)
                .foregroundStyle(HiAirColors.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
            if !viewModel.headline.isEmpty, viewModel.headline != "-" {
                Text(viewModel.headline)
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirColors.Text.secondary)
            }
        }
        .v2Card()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var checklistSection: some View {
        if !session.checklistHidden {
            VStack(alignment: .leading, spacing: 8) {
                HiAirSectionHeader(
                    title: session.l("dashboard.get_started.title"),
                    actionTitle: session.l("dashboard.get_started.hide")
                ) {
                    session.checklistHidden = true
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
                                .font(HiAirTypography.bodyMD)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .v2Card()
        }
    }

    private var locationStatusMessage: String {
        switch locationService.serviceState {
        case .servicesDisabled:
            return session.l("location.services_disabled")
        case .timeout:
            return session.l("location.timeout")
        case .denied, .restricted:
            return session.l("location.denied.body")
        default:
            return session.l("dashboard.empty.location_missing")
        }
    }

    @ViewBuilder
    private var emptyStateSections: some View {
        if !session.hasValidLocation {
            VStack(alignment: .leading, spacing: 10) {
                Text(session.l("location.denied.title"))
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                Text(locationStatusMessage)
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
                HStack(spacing: 10) {
                    Button(session.l("location.retry")) {
                        Task { _ = await session.bootstrapLocationFromDevice(locationService: locationService) }
                    }
                    .buttonStyle(HiAirGradientButtonStyle())
                    if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
                        Button(session.l("location.open_settings")) {
                            locationService.openAppSettings()
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                    }
                }
            }
            .v2Card()
        }

        if session.profileId.isEmpty {
            ProfileBootstrapCard(
                locationService: locationService,
                onReady: { await reloadDashboard() }
            )
        }
    }

    @ViewBuilder
    private func riskHeroSection(width: CGFloat) -> some View {
        if let score = riskScore {
            HiAirCard {
                HiAirRiskGaugeView(
                    score: score,
                    sectionLabel: session.l("dashboard.current_risk_title"),
                    statusLabel: moodTitle,
                    riskLevel: viewModel.riskLevel,
                    reason: riskReason,
                    diameter: min(width * 0.52, 220)
                )
            }
        }
    }

    @ViewBuilder
    private var todaysAirSection: some View {
        if let env = viewModel.environmental {
            VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
                HStack {
                    Text(session.l("dashboard.section.todays_air"))
                        .font(HiAirTypography.titleMD)
                        .foregroundStyle(HiAirColors.Text.primary)
                    Spacer()
                    HiAirStatusChip(
                        riskLevel: viewModel.riskLevel,
                        label: session.l(sourceLabelKey(for: env.source))
                    )
                }
                HStack(spacing: HiAirSpacing.md) {
                    HiAirOrbLogoView(
                        size: 56,
                        riskLevel: viewModel.riskLevel,
                        presentation: .brand
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(weatherTitle)
                            .font(HiAirTypography.titleMD)
                            .foregroundStyle(HiAirColors.Text.primary)
                        Text("\(session.l("dashboard.mood_prefix")): \(moodTitle)")
                            .font(HiAirTypography.bodyMD)
                            .foregroundStyle(HiAirColors.Text.secondary)
                    }
                    Spacer()
                }
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: HiAirSpacing.sm
                ) {
                    airMetricTile(
                        title: session.l("dashboard.metric.aqi"),
                        value: "\(env.aqi)",
                        icon: "aqi.medium",
                        tooltip: "dashboard.tooltip.aqi"
                    )
                    airMetricTile(
                        title: session.l("dashboard.metric.pm25"),
                        value: String(format: "%.1f", env.pm25),
                        icon: "aqi.low",
                        tooltip: "dashboard.tooltip.pm25"
                    )
                    airMetricTile(
                        title: session.l("dashboard.metric.ozone"),
                        value: String(format: "%.1f", env.ozone),
                        icon: "sun.max.fill",
                        tooltip: "dashboard.tooltip.ozone"
                    )
                    airMetricTile(
                        title: session.l("dashboard.metric.heat_index"),
                        value: String(format: "%.0f°", env.feelsLike),
                        icon: "thermometer.medium",
                        tooltip: "dashboard.tooltip.heat_index"
                    )
                }
            }
            .v2Card()
            .onAppear { ProductAnalytics.track("risk_breakdown_viewed") }
        } else if !viewModel.loading {
            HiAirEmptyStateView(
                title: session.l("dashboard.section.todays_air"),
                message: session.l("dashboard.empty.api_unavailable"),
                actionTitle: session.l("common.retry"),
                action: { Task { await reloadDashboard() } }
            )
            .v2Card()
        }
    }

    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            HStack {
                HiAirSectionHeader(title: session.l("dashboard.section.quick_actions"))
                infoButton("dashboard.recommendations_tooltip")
            }
            if viewModel.actions.isEmpty {
                Text(session.l("dashboard.no_actions"))
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirColors.Text.secondary)
            } else {
                ForEach(Array(viewModel.actions.prefix(3).enumerated()), id: \.offset) { index, action in
                    actionTile(
                        icon: index == 0 ? "drop.fill" : (index == 1 ? "wind" : "figure.walk"),
                        text: action
                    )
                }
            }
            HStack(spacing: HiAirSpacing.sm) {
                Button(session.l("dashboard.log_symptoms")) {
                    session.selectedTab = 3
                    session.markChecklistItem("recommendations", done: true)
                }
                .buttonStyle(HiAirGradientButtonStyle())
                Button(session.l("tab.planner")) {
                    session.selectedTab = 1
                    session.markChecklistItem("hourly", done: true)
                }
                .buttonStyle(HiAirSecondaryButtonStyle())
            }
            Button(viewModel.loading ? session.l("dashboard.loading") : session.l("dashboard.recompute")) {
                Task {
                    if session.profileId.isEmpty {
                        // Explicit user recompute — do not reuse a prior terminal ensure failure.
                        session.beginExplicitProfileEnsureCycle()
                        _ = await session.ensureProfileIdIfNeeded()
                    }
                    session.markChecklistItem("risk", done: true)
                    await reloadDashboard(skipProfileEnsure: true)
                }
            }
            .buttonStyle(HiAirSecondaryButtonStyle())
            .disabled(viewModel.loading)
        }
        .v2Card()
    }

    @ViewBuilder
    private var safeWindowsSection: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            HStack {
                HiAirSectionHeader(title: session.l("dashboard.safe_windows"))
                infoButton("dashboard.safe_windows_tooltip")
            }
            if safeWindows.isEmpty {
                Text(session.l("dashboard.no_safe_windows"))
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirColors.Text.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(safeWindows, id: \.self) { window in
                            HiAirStatusChip(riskLevel: "low", label: window)
                        }
                    }
                }
            }
        }
        .v2Card()
    }

    private func airMetricTile(title: String, value: String, icon: String, tooltip: String) -> some View {
        Button {
            activeInfoKey = InfoTerm(id: tooltip)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(riskColor)
                    Text(title)
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirColors.Text.secondary)
                        .lineLimit(1)
                }
                Text(value)
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirColors.Text.primary)
            }
            .padding(HiAirSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hiAirTileSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(value)")
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
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.primary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HiAirColors.Overlay.subtle, in: RoundedRectangle(cornerRadius: 12))
    }

    private func infoButton(_ key: String) -> some View {
        Button {
            activeInfoKey = InfoTerm(id: key)
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(HiAirColors.Text.tertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.l("common.info"))
    }

    private func sourceLabelKey(for source: String) -> String {
        switch source.lowercased() {
        case "live":
            return "dashboard.source_live"
        case "cached":
            return "dashboard.source_cached"
        default:
            // Never label production UI as "sample/demo" for end users.
            return "dashboard.source_estimated"
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
            VStack(alignment: .leading, spacing: HiAirSpacing.md) {
                Text(text)
                    .font(HiAirTypography.bodyLG)
                    .foregroundStyle(HiAirColors.Text.primary)
                Spacer()
            }
            .padding(HiAirSpacing.lg)
            .background(HiAirGradients.timeOfDay().ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(closeTitle) { dismiss() }
                        .foregroundStyle(HiAirColors.Cta.gradientStart)
                }
            }
        }
    }
}

