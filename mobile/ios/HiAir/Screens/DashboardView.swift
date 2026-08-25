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
    @Published var safeWindowModels: [AirSafeWindow] = []
    @Published var environmental: AirEnvironmentalInput?
    @Published var hazardsResponse: HazardsResponse?
    @Published var familyRiskOverview: FamilyRiskOverviewResponse?
    @Published var wearableToday: WearableTodayResponse?
    @Published var healthSummary: HealthSummaryResponseDTO?
    @Published var morningReport: AIReportResponseDTO?
    @Published var wearableConnectionState: WearableConnectionState = .notConnected
    @Published var loadFailed = false
    @Published var freshness: String = ""
    @Published var dataQuality: String = ""
    @Published var exposureReducedMarked = false
    @Published var highRiskAvoidedMarked = false
    @Published var protectedDayStatus = ""
    @Published var travelSession: TravelSession?

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
        exposureReducedMarked = false
        highRiskAvoidedMarked = false
        protectedDayStatus = ""
        familyRiskOverview = nil
        travelSession = nil
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
            safeWindowModels = []
            environmental = nil
            hazardsResponse = nil
            familyRiskOverview = nil
            freshness = ""
            dataQuality = ""
            wearableToday = nil
            healthSummary = nil
            morningReport = nil
            return
        }
        do {
            ProductAnalytics.track("forecast_fetch_started", properties: ["surface": "dashboard"])
            // Phase 1: only current-risk. Starting enrichments via async let here
            // saturates the API container and Open-Meteo before the hero can paint.
            let result = try await apiClient.fetchCurrentRisk(
                profileId: profileId,
                userId: userId,
                accessToken: accessToken
            )
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
            freshness = result.freshness ?? result.environmental.source
            dataQuality = result.dataQuality ?? ""
            safeWindowModels = result.risk.safeWindows
            let locale = Locale(identifier: language)
            let zone = HiAirHumanDate.timeZone(identifier: result.environmental.timezone)
            safeWindowLabels = result.risk.safeWindows.map { window in
                Self.formatSafeWindow(
                    type: window.type,
                    start: window.start,
                    end: window.end,
                    language: language,
                    locale: locale,
                    timeZone: zone
                )
            }
            let ventilationLabels = (result.risk.ventilationWindows ?? []).map { window in
                Self.formatSafeWindow(
                    type: window.type,
                    start: window.start,
                    end: window.end,
                    language: language,
                    locale: locale,
                    timeZone: zone
                )
            }
            if !ventilationLabels.isEmpty {
                safeWindowLabels.append(contentsOf: ventilationLabels)
            }
            if let firstWindow = result.risk.safeWindows.first {
                nearestSafeWindow = Self.formatSafeWindow(
                    type: firstWindow.type,
                    start: firstWindow.start,
                    end: firstWindow.end,
                    language: language,
                    locale: locale,
                    timeZone: zone
                )
            } else {
                nearestSafeWindow = HiAirL10n.t("dashboard.no_safe_window", lang: language)
            }
            // End skeleton as soon as risk is ready; enrichments fill in below.
            loading = false
            hasLoadedOnce = true
            ProductAnalytics.track(
                "forecast_fetch_succeeded",
                properties: [
                    "freshness": freshness,
                    "quality": dataQuality,
                    "hours": String(result.risk.safeWindows.isEmpty ? 0 : 24),
                ]
            )

            // Phase 2: start only after hero paint so they cannot starve current-risk.
            async let hazardsTask = apiClient.fetchHazards(
                profileId: profileId,
                userId: userId,
                accessToken: accessToken
            )
            async let familyRiskTask = apiClient.fetchFamilyRiskOverview(
                userId: userId,
                accessToken: accessToken
            )
            async let wearableTask = apiClient.fetchWearableToday(userId: userId, accessToken: accessToken)
            async let summaryTask = apiClient.fetchHealthSummary(userId: userId, accessToken: accessToken)
            async let travelTask = apiClient.fetchTravelSession(
                userId: userId,
                accessToken: accessToken
            )
            hazardsResponse = try? await hazardsTask
            familyRiskOverview = try? await familyRiskTask
            wearableToday = try? await wearableTask
            healthSummary = try? await summaryTask
            travelSession = try? await travelTask
            morningReport = try? await apiClient.fetchAIReport(
                kind: "morning",
                profileId: profileId,
                userId: userId,
                accessToken: accessToken
            )
        } catch {
            ProductAnalytics.track("forecast_fetch_failed", properties: ["surface": "dashboard"])
            loadFailed = true
            riskLevel = "error"
            headline = HiAirL10n.t("dashboard.error", lang: language)
            explanation = HiAirL10n.t("dashboard.empty.api_unavailable", lang: language)
            actions = []
            nearestSafeWindow = ""
            safeWindowLabels = []
            safeWindowModels = []
            environmental = nil
            hazardsResponse = nil
            familyRiskOverview = nil
            freshness = ""
            dataQuality = ""
            wearableToday = nil
            healthSummary = nil
            morningReport = nil
        }
    }

    static func isElevatedRisk(_ level: String) -> Bool {
        let normalized = level.lowercased().replacingOccurrences(of: " ", with: "_")
        return normalized == "high" || normalized == "very_high"
    }

    func markExposureReduced(profileId: String, userId: String, accessToken: String, language: String) async {
        await recordProtectedDayEvent(
            profileId: profileId,
            userId: userId,
            accessToken: accessToken,
            language: language,
            eventType: "poor_air_exposure_reduced",
            successKey: "dashboard.protected.exposure_done"
        ) { [weak self] status in
            self?.exposureReducedMarked = true
            self?.protectedDayStatus = status
        } onFailure: { [weak self] status in
            self?.protectedDayStatus = status
        }
    }

    func markHighRiskAvoided(profileId: String, userId: String, accessToken: String, language: String) async {
        await recordProtectedDayEvent(
            profileId: profileId,
            userId: userId,
            accessToken: accessToken,
            language: language,
            eventType: "high_risk_period_avoided",
            successKey: "dashboard.protected.risk_avoided_done"
        ) { [weak self] status in
            self?.highRiskAvoidedMarked = true
            self?.protectedDayStatus = status
        } onFailure: { [weak self] status in
            self?.protectedDayStatus = status
        }
    }

    private func recordProtectedDayEvent(
        profileId: String,
        userId: String,
        accessToken: String,
        language: String,
        eventType: String,
        successKey: String,
        onSuccess: @escaping (String) -> Void,
        onFailure: @escaping (String) -> Void
    ) async {
        guard !profileId.isEmpty else { return }
        do {
            _ = try await apiClient.createProtectedDayEvent(
                payload: ProtectedDayEventCreateRequest(
                    profileId: profileId,
                    eventType: eventType,
                    eventDate: nil
                ),
                userId: userId,
                accessToken: accessToken
            )
            onSuccess(HiAirL10n.t(successKey, lang: language))
        } catch {
            onFailure(HiAirL10n.t("planner.activity.mark_planned_failed", lang: language))
        }
    }

    private static func formatSafeWindow(
        type: String,
        start: String,
        end: String,
        language: String,
        locale: Locale,
        timeZone: TimeZone = .autoupdatingCurrent
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
        let range = HiAirHumanDate.timeRange(
            fromISO: start,
            toISO: end,
            locale: locale,
            timeZone: timeZone,
            unavailable: ""
        )
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
        if viewModel.loading { return session.l("dashboard.freshness_updating") }
        switch viewModel.freshness.lowercased() {
        case "cached":
            return session.l("dashboard.source_cached")
        case "stale":
            return session.l("dashboard.freshness_stale")
        case "live":
            return session.l("dashboard.freshness_fresh")
        default:
            return session.l("dashboard.freshness_fresh")
        }
    }

    private var showLiveRiskContent: Bool {
        viewModel.hasLoadedOnce && !viewModel.riskLevel.isEmpty && viewModel.riskLevel != "unknown" && !viewModel.loadFailed
    }

    private var safeWindows: [String] {
        viewModel.safeWindowLabels
    }

    private var locationLabel: String {
        if let travel = viewModel.travelSession, travel.active, let name = travel.placeName, !name.isEmpty {
            return name
        }
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
                    homeChrome
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
                        environmentalRiskCard(width: width)
                        weatherAQIRow
                        recommendationsCard
                        outdoorWindowCard
                        hazardsSection
                        travelSection
                        familyRiskSection
                        protectedDaySection
                        healthMetricsSection
                        wearableLoadSection
                        quickActionsSection
                    }

                    if showStarterChecklist {
                        checklistSection
                    }
                }
                .hiAirContentWidth(for: width)
                .hiAirScreenPadding(for: width)
                .padding(.bottom, HiAirSpacing.tabBarClearance)
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
            let hadProfile = !session.profileId.isEmpty
            let profileBefore = session.profileId
            let locationRevisionBefore = session.locationRevision
            if UITestBootstrap.disableAutoProfileBootstrap {
                await reloadDashboard()
            } else if hadProfile {
                // Returning user: paint from cached profile while prepare runs;
                // re-fetch only when prepare changes profile or coordinates.
                async let prepare = session.prepareSessionForDataFetch(locationService: locationService)
                await reloadDashboard(skipProfileEnsure: true)
                _ = await prepare
                let profileChanged = session.profileId != profileBefore
                let locationChanged = session.locationRevision != locationRevisionBefore
                if profileChanged || locationChanged {
                    await reloadDashboard(skipProfileEnsure: true)
                }
            } else {
                _ = await session.prepareSessionForDataFetch(locationService: locationService)
                await reloadDashboard(skipProfileEnsure: true)
            }
            session.markChecklistItem("risk", done: true)
            StartupDiagnostics.track(
                "dashboard_refresh_succeeded",
                success: !viewModel.loadFailed,
                profilePresent: !session.profileId.isEmpty
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .hiairTravelSessionDidChange)) { _ in
            session.locationRevision += 1
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
            if let context = notification.object as? ProfileLocationUpdateContext,
               context.source == .placeNameResolved {
                return
            }
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

    private func dg(_ key: String) -> String {
        HiAirDeepGlassCopy.t(key, lang: session.preferredLanguage)
    }

    private var greetingName: String {
        let local = session.email.split(separator: "@").first.map(String.init) ?? ""
        let token = local.split(separator: ".").first.map(String.init) ?? local
        guard token.count >= 2, token.allSatisfy({ $0.isLetter || $0.isNumber }) else { return "" }
        return token.prefix(1).uppercased() + token.dropFirst().lowercased()
    }

    private var riskLevelLabel: String {
        switch viewModel.riskLevel.lowercased() {
        case "low": return dg("spectrum.low")
        case "high": return dg("spectrum.high")
        case "very_high", "very high": return dg("spectrum.very_high")
        default: return dg("spectrum.moderate")
        }
    }

    @ViewBuilder
    private var homeChrome: some View {
        HStack(spacing: 10) {
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
                .font(HiAirTypography.caption.weight(.semibold))
                .foregroundStyle(HiAirColors.Text.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .hiAirGlassSurface(prominence: .compact, cornerRadius: HiAirRadius.chip)
            }
            .buttonStyle(.plain)

            Spacer()
            HiAirLivePill(
                isLive: !viewModel.loading && viewModel.environmental != nil,
                label: freshnessLabel
            )
            Image("HiAirWordmark")
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(height: 22)
                .accessibilityLabel("HiAir")
        }

        VStack(alignment: .leading, spacing: 6) {
            greetingText
                .font(HiAirTypography.displayLG)
                .accessibilityAddTraits(.isHeader)
            Text(dg("tagline.smarter"))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.secondary)
        }
    }

    private var greetingText: Text {
        let hour = Calendar.current.component(.hour, from: Date())
        let hello: String
        if hour < 12 {
            hello = dg("greeting.morning")
        } else if hour < 18 {
            hello = dg("greeting.afternoon")
        } else {
            hello = dg("greeting.evening")
        }
        if greetingName.isEmpty {
            return Text(hello).foregroundColor(HiAirColors.Text.primary)
        }
        return Text(hello + ", ").foregroundColor(HiAirColors.Text.primary)
            + Text(greetingName).foregroundColor(HiAirColors.Spectrum.violet)
    }

    @ViewBuilder
    private func environmentalRiskCard(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.md) {
            HStack {
                Label(dg("env_risk"), systemImage: "checkmark.shield")
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirColors.Text.primary)
                Spacer()
                infoButton("dashboard.current_risk_title")
            }
            HStack {
                Spacer()
                HiAirDeepGlassOrb(
                    score: riskScore ?? 0,
                    levelLabel: riskLevelLabel,
                    riskLevel: viewModel.riskLevel,
                    diameter: min(width * 0.58, 240)
                )
                Spacer()
            }
            HiAirRiskSpectrumBar(score: riskScore ?? 45, lang: session.preferredLanguage)
        }
        .padding(HiAirSpacing.md)
        .hiAirGlassSurface(prominence: .hero, glow: riskColor)
    }

    @ViewBuilder
    private var weatherAQIRow: some View {
        if let env = viewModel.environmental {
            HStack(spacing: 12) {
                HiAirGlassMetricTile(
                    title: dg("weather"),
                    value: String(format: "%.0f°C", env.temperature),
                    subtitle: dg("outdoor_now"),
                    footnote: weatherFootnote(env),
                    icon: (env.uv ?? 0) >= 5 ? "sun.max.fill" : "cloud.sun.fill",
                    accent: HiAirColors.Risk.moderate
                )
                HiAirGlassMetricTile(
                    title: dg("aqi"),
                    value: env.aqi.map { "\($0)" } ?? session.l("common.unavailable"),
                    subtitle: env.aqi.map(aqiStatusLabel) ?? session.l("dashboard.hazards.unavailable"),
                    footnote: env.pm25.map { String(format: "PM2.5 %.0f µg/m³", $0) } ?? "PM2.5 —",
                    icon: "aqi.medium",
                    accent: aqiAccent(env.aqi ?? 0)
                )
            }
            .onAppear { ProductAnalytics.track("risk_breakdown_viewed") }
        }
    }

    private func weatherFootnote(_ env: AirEnvironmentalInput) -> String {
        let humidity = env.humidity.map { String(format: "%.0f%%", $0) } ?? "—"
        return String(
            format: "%@ %.0f° · %@ %@",
            dg("feels"),
            env.feelsLike,
            dg("humidity"),
            humidity
        )
    }

    private func aqiAccent(_ aqi: Int) -> Color {
        if aqi <= 50 { return HiAirColors.Risk.low }
        if aqi <= 100 { return HiAirColors.Risk.moderate }
        if aqi <= 150 { return HiAirColors.Risk.high }
        return HiAirColors.Risk.veryHigh
    }

    private func aqiStatusLabel(_ aqi: Int) -> String {
        if aqi <= 50 { return dg("good") }
        if aqi <= 100 { return dg("spectrum.moderate") }
        if aqi <= 150 { return dg("spectrum.high") }
        return dg("spectrum.very_high")
    }

    @ViewBuilder
    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(dg("recommendations"), systemImage: "leaf.fill")
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirColors.Text.primary)
                Spacer()
                Button(dg("view_all")) {
                    session.selectedTab = 1
                    session.markChecklistItem("recommendations", done: true)
                }
                .font(HiAirTypography.caption.weight(.semibold))
                .foregroundStyle(HiAirColors.Spectrum.cyan)
            }
            let items = viewModel.actions.isEmpty ? [riskReason] : Array(viewModel.actions.prefix(2))
            ForEach(Array(items.enumerated()), id: \.offset) { index, text in
                Button {
                    session.selectedTab = 1
                    session.markChecklistItem("recommendations", done: true)
                } label: {
                    HiAirRecommendationRow(
                        icon: index == 0 ? "facemask" : "leaf.fill",
                        text: text,
                        accent: index == 0 ? HiAirColors.Spectrum.electricBlue : HiAirColors.Spectrum.violet
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(HiAirSpacing.md)
        .hiAirGlassSurface(prominence: .standard, glow: HiAirColors.Spectrum.violet)
    }

    @ViewBuilder
    private var outdoorWindowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(dg("outdoor_window"), systemImage: "clock.fill")
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirColors.Text.primary)
                Spacer()
                Text(dg("today"))
                    .font(HiAirTypography.caption.weight(.semibold))
                    .foregroundStyle(HiAirColors.Spectrum.cyan)
            }
            HiAirOutdoorWindowBar(
                segments: outdoorSegments,
                summary: dg("best_window_prefix") + " ",
                highlightRange: nearestWindowRange,
                todayLabel: ""
            )
        }
        .padding(HiAirSpacing.md)
        .hiAirGlassSurface(prominence: .standard, glow: HiAirColors.Risk.low)
    }

    private var outdoorSegments: [Color] {
        let buckets = [(6, 9), (9, 12), (12, 15), (15, 18), (18, 21), (21, 24)]
        let base = HiAirRiskStyle.color(for: viewModel.riskLevel)
        return buckets.map { start, end in
            let inWindow = viewModel.safeWindowModels.contains { window in
                guard let windowStart = HiAirDeepGlassTime.hour(from: window.start),
                      let windowEnd = HiAirDeepGlassTime.hour(from: window.end)
                else { return false }
                return windowStart < end && windowEnd > start
            }
            return inWindow ? HiAirColors.Risk.low : base
        }
    }

    private var nearestWindowRange: String {
        if let first = viewModel.nearestSafeWindow.split(separator: ":").last {
            let trimmed = first.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
        }
        return viewModel.nearestSafeWindow
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
                        value: metricText(env.aqi.map { "\($0)" }),
                        icon: "aqi.medium",
                        tooltip: "dashboard.tooltip.aqi"
                    )
                    airMetricTile(
                        title: session.l("dashboard.metric.pm25"),
                        value: metricText(env.pm25.map { String(format: "%.1f", $0) }),
                        icon: "aqi.low",
                        tooltip: "dashboard.tooltip.pm25"
                    )
                    airMetricTile(
                        title: session.l("dashboard.metric.ozone"),
                        value: metricText(env.ozone.map { String(format: "%.1f", $0) }),
                        icon: "sun.max.fill",
                        tooltip: "dashboard.tooltip.ozone"
                    )
                    if let no2 = env.no2 {
                        airMetricTile(
                            title: session.l("dashboard.metric.no2"),
                            value: metricText(String(format: "%.1f", no2)),
                            icon: "car.side.fill",
                            tooltip: "dashboard.tooltip.no2"
                        )
                    }
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
    private var hazardsSection: some View {
        if let hazards = viewModel.hazardsResponse {
            VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
                HStack {
                    Text(session.l("dashboard.hazards.title"))
                        .font(HiAirTypography.titleMD)
                        .foregroundStyle(HiAirColors.Text.primary)
                    Spacer()
                    HiAirStatusChip(
                        riskLevel: hazards.assessment.overallLevel,
                        label: hazardLevelLabel(hazards.assessment.overallLevel)
                    )
                }
                if hazards.assessment.hazards.isEmpty {
                    Text(session.l("dashboard.hazards.empty"))
                        .font(HiAirTypography.bodyMD)
                        .foregroundStyle(HiAirColors.Text.secondary)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 120), spacing: HiAirSpacing.xs)],
                        alignment: .leading,
                        spacing: HiAirSpacing.xs
                    ) {
                        ForEach(hazards.assessment.hazards) { item in
                            if item.available {
                                HiAirStatusChip(
                                    riskLevel: item.level,
                                    label: "\(hazardTypeLabel(item.hazard)) · \(hazardLevelLabel(item.level))"
                                )
                            } else {
                                Text("\(hazardTypeLabel(item.hazard)) · \(session.l("dashboard.hazards.unavailable"))")
                                    .font(HiAirTypography.caption.weight(.semibold))
                                    .foregroundStyle(HiAirColors.Text.tertiary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(HiAirColors.Text.tertiary.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }
            }
            .v2Card()
        }
    }

    private func hazardTypeLabel(_ hazard: String) -> String {
        session.l("hazard.type.\(hazard.lowercased())")
    }

    private func hazardLevelLabel(_ level: String) -> String {
        let normalized = level.lowercased().replacingOccurrences(of: " ", with: "_")
        return session.l("hazard.level.\(normalized)")
    }

    @ViewBuilder
    private var travelSection: some View {
        if let travel = viewModel.travelSession, travel.active {
            VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
                Text(session.l("dashboard.travel.title"))
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirColors.Text.primary)
                Text(
                    String(
                        format: session.l("dashboard.travel.active"),
                        travel.placeName ?? session.l("dashboard.travel.place_fallback")
                    )
                )
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.secondary)
                Text(session.l("dashboard.travel.subtitle"))
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirColors.Text.tertiary)
            }
            .v2Card()
        }
    }

    @ViewBuilder
    private var familyRiskSection: some View {
        if let overview = viewModel.familyRiskOverview, !overview.members.isEmpty {
            VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
                Text(session.l("dashboard.family.title"))
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirColors.Text.primary)
                if let highest = overview.highestRiskLevel, !highest.isEmpty {
                    Text("\(session.l("dashboard.family.highest")) \(hazardLevelLabel(highest))")
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirColors.Text.secondary)
                }
                ForEach(overview.members, id: \.memberLinkId) { member in
                    let name = member.label?.isEmpty == false ? member.label! : member.relation
                    Text(familyMemberRiskLine(member, displayName: name))
                        .font(HiAirTypography.bodyMD)
                        .foregroundStyle(HiAirColors.Text.secondary)
                }
            }
            .v2Card()
        }
    }

    private func familyMemberRiskLine(_ member: FamilyMemberRiskLine, displayName: String) -> String {
        if !member.available {
            return "\(displayName) · \(session.l("settings.family.risk_unavailable"))"
        }
        let level = hazardLevelLabel(member.riskLevel)
        return "\(displayName) · \(level) (\(member.riskScore))"
    }

    @ViewBuilder
    private var protectedDaySection: some View {
        if DashboardViewModel.isElevatedRisk(viewModel.riskLevel), !session.profileId.isEmpty {
            VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
                Text(session.l("dashboard.protected.title"))
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirColors.Text.primary)
                Text(session.l("dashboard.protected.subtitle"))
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirColors.Text.secondary)
                if !viewModel.exposureReducedMarked {
                    Button(session.l("dashboard.protected.exposure")) {
                        Task {
                            await viewModel.markExposureReduced(
                                profileId: session.profileId,
                                userId: session.userId,
                                accessToken: session.accessToken,
                                language: session.preferredLanguage
                            )
                        }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                }
                if !viewModel.safeWindowLabels.isEmpty, !viewModel.highRiskAvoidedMarked {
                    Button(session.l("dashboard.protected.risk_avoided")) {
                        Task {
                            await viewModel.markHighRiskAvoided(
                                profileId: session.profileId,
                                userId: session.userId,
                                accessToken: session.accessToken,
                                language: session.preferredLanguage
                            )
                        }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                }
                if !viewModel.protectedDayStatus.isEmpty {
                    Text(viewModel.protectedDayStatus)
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirColors.Text.secondary)
                }
            }
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

    private func metricText(_ value: String?) -> String {
        value ?? session.l("dashboard.metric.unavailable")
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

