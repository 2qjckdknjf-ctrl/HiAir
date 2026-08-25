import SwiftUI

@MainActor
final class DailyPlannerViewModel: ObservableObject {
    @Published var loading = false
    @Published var hourlyItems: [AirHourlyRiskPoint] = []
    @Published var safeWindows: [AirSafeWindow] = []
    @Published var ventilationWindows: [AirSafeWindow] = []
    @Published var statusText = ""
    @Published var premiumLocked = false
    @Published var timezoneIdentifier = ""
    @Published var freshness = ""
    @Published var dataQuality = ""
    @Published var forecastAvailable = true
    @Published var missingMetrics: [String] = []
    @Published var sources: [String] = []

    @Published var activities: [ActivityCatalogItem] = []
    @Published var selectedActivity = "walking"
    @Published var selectedPlaceId: String? = nil
    @Published var savedPlaces: [SavedPlace] = []
    @Published var activityPlanMarked = false
    @Published var activityPlanMarkStatus = ""
    @Published var ventilationWindowMarked = false
    @Published var ventilationMarkStatus = ""
    @Published var activityPlanLoading = false
    @Published var activityPlan: ActivityPlanResponse?
    @Published var activityStatusText = ""
    @Published var activityPremiumLocked = false
    @Published var activityTimezoneIdentifier = ""

    @Published private(set) var forecastSurface: PlannerForecastSurface = .idle
    @Published private(set) var activitySurface: PlannerActivitySurface = .idle

    var hasSuccessfulActivityPlan: Bool {
        activitySurface.hasDisplayableData
    }

    var hasForecastData: Bool {
        forecastSurface.hasDisplayableData || !hourlyItems.isEmpty || !safeWindows.isEmpty
    }

    private let apiClient = APIClient.live()

    func refresh(
        profileId: String,
        userId: String,
        accessToken: String,
        language: String,
        onPremiumRequired: (() -> Void)? = nil
    ) async {
        loading = true
        forecastSurface = .loading
        defer { loading = false }
        premiumLocked = false
        ventilationWindowMarked = false
        ventilationMarkStatus = ""
        await loadActivities(userId: userId, accessToken: accessToken)
        do {
            ProductAnalytics.track("forecast_fetch_started", properties: ["surface": "planner"])
            let planner = try await apiClient.fetchAirDayPlan(
                profileId: profileId,
                userId: userId,
                accessToken: accessToken
            )
            hourlyItems = planner.isForecastAvailable ? planner.hourlyRisk : []
            safeWindows = planner.isForecastAvailable
                ? planner.safeWindows.filter { $0.type.lowercased() != "ventilation" }
                : []
            ventilationWindows = planner.isForecastAvailable ? planner.ventilationWindows : []
            timezoneIdentifier = planner.timezone
            freshness = planner.freshness ?? ""
            dataQuality = planner.dataQuality ?? ""
            forecastAvailable = planner.isForecastAvailable
            missingMetrics = planner.missingMetrics ?? []
            sources = planner.sources ?? []
            if !planner.isForecastAvailable {
                let message = HiAirL10n.t("planner.forecast_unavailable", lang: language)
                forecastSurface = .unavailable(message: message)
                statusText = message
                ProductAnalytics.track("planner_forecast_unavailable", properties: ["quality": dataQuality])
            } else if planner.dataQuality == "partial" {
                var partial = HiAirL10n.t("planner.forecast_partial", lang: language)
                if !missingMetrics.isEmpty {
                    let listed = missingMetrics.prefix(4).joined(separator: ", ")
                    partial += " (\(listed))"
                }
                forecastSurface = .partial(hours: planner.hourlyRisk.count, message: partial)
                statusText = partial
                ProductAnalytics.track(
                    "planner_real_forecast_loaded",
                    properties: ["quality": "partial", "hours": String(planner.hourlyRisk.count)]
                )
            } else {
                forecastSurface = .loaded(hours: planner.hourlyRisk.count)
                statusText = String(
                    format: HiAirL10n.t("planner.loaded", lang: language),
                    planner.hourlyRisk.count
                )
                ProductAnalytics.track(
                    "planner_real_forecast_loaded",
                    properties: [
                        "quality": planner.dataQuality ?? "complete",
                        "hours": String(planner.hourlyRisk.count),
                        "freshness": planner.freshness ?? "",
                    ]
                )
            }
            await refreshActivityPlan(
                profileId: profileId,
                userId: userId,
                accessToken: accessToken,
                language: language,
                onPremiumRequired: onPremiumRequired
            )
        } catch let error as APIError {
            ProductAnalytics.track("forecast_fetch_failed", properties: ["surface": "planner"])
            let premiumCode: Int? = {
                if case .server(let code) = error { return code }
                if case .serverWithDetail(let code, _) = error { return code }
                return nil
            }()
            if premiumCode == 402 {
                premiumLocked = true
                activityPremiumLocked = true
                onPremiumRequired?()
                let message = HiAirL10n.t("planner.premium_required", lang: language)
                forecastSurface = .premiumLocked(message: message)
                activitySurface = .premiumLocked(message: message)
                statusText = message
                activityStatusText = message
            } else {
                let message = HiAirL10n.t("planner.empty.unavailable.body", lang: language)
                forecastSurface = .failed(message: message)
                statusText = message
            }
            hourlyItems = []
            safeWindows = []
            ventilationWindows = []
            forecastAvailable = false
        } catch {
            ProductAnalytics.track("forecast_fetch_failed", properties: ["surface": "planner"])
            let message = HiAirL10n.t("planner.empty.unavailable.body", lang: language)
            forecastSurface = .failed(message: message)
            statusText = message
            hourlyItems = []
            safeWindows = []
            ventilationWindows = []
            forecastAvailable = false
        }
    }

    func loadActivities(userId: String, accessToken: String) async {
        do {
            let catalog = try await apiClient.fetchActivityCatalog(
                userId: userId,
                accessToken: accessToken
            )
            activities = catalog.activities
            if !activities.contains(where: { $0.activity == selectedActivity }),
               let first = activities.first {
                selectedActivity = first.activity
            }
        } catch {
            if activities.isEmpty {
                activities = Self.fallbackActivities
            }
        }
        await loadSavedPlaces(userId: userId, accessToken: accessToken)
    }

    func loadSavedPlaces(userId: String, accessToken: String) async {
        do {
            let response = try await apiClient.listPlaces(userId: userId, accessToken: accessToken)
            savedPlaces = response.places
            if let selectedPlaceId,
               !savedPlaces.contains(where: { $0.id == selectedPlaceId }) {
                self.selectedPlaceId = nil
            }
        } catch {
            // Places are optional for planner; keep previous list on failure.
        }
    }

    func refreshActivityPlan(
        profileId: String,
        userId: String,
        accessToken: String,
        language: String,
        onPremiumRequired: (() -> Void)? = nil
    ) async {
        guard !profileId.isEmpty else { return }
        activityPlanLoading = true
        activitySurface = .loading
        defer { activityPlanLoading = false }
        activityPremiumLocked = false
        activityPlanMarked = false
        activityPlanMarkStatus = ""
        do {
            ProductAnalytics.track(
                "activity_plan_fetch_started",
                properties: ["activity": selectedActivity]
            )
            let payload = ActivityPlanRequest(
                profileId: profileId,
                activity: selectedActivity,
                durationMinutes: nil,
                intensity: nil,
                earliestStart: nil,
                latestStart: nil,
                placeId: selectedPlaceId
            )
            let plan = try await apiClient.createActivityPlan(
                payload: payload,
                userId: userId,
                accessToken: accessToken
            )
            activityPlan = plan
            activityTimezoneIdentifier = plan.timezone
            activityStatusText = ""
            if !plan.isForecastAvailable {
                let message = HiAirL10n.t("planner.activity.forecast_unavailable", lang: language)
                activitySurface = .failed(message: message)
                activityStatusText = message
            } else if plan.dataQuality == "partial" {
                let message = HiAirL10n.t("planner.forecast_partial", lang: language)
                activitySurface = .partial(message: message)
                activityStatusText = message
            } else if plan.windows.isEmpty {
                let message = HiAirL10n.t("planner.activity.no_windows", lang: language)
                activitySurface = .empty(message: message)
                activityStatusText = message
            } else {
                activitySurface = .loaded(windowCount: plan.windows.count)
                activityStatusText = ""
            }
            ProductAnalytics.track(
                "activity_plan_loaded",
                properties: [
                    "activity": plan.activity,
                    "windows": String(plan.windows.count),
                    "quality": plan.dataQuality ?? "complete",
                ]
            )
            if plan.isForecastAvailable, !plan.windows.isEmpty {
                ProductAnalytics.track(
                    "activity_plan_created",
                    properties: [
                        "activity": plan.activity,
                        "windows": String(plan.windows.count),
                    ]
                )
            }
        } catch let error as APIError {
            ProductAnalytics.track(
                "activity_plan_fetch_failed",
                properties: ["activity": selectedActivity]
            )
            let premiumCode: Int? = {
                if case .server(let code) = error { return code }
                if case .serverWithDetail(let code, _) = error { return code }
                return nil
            }()
            if premiumCode == 402 {
                activityPremiumLocked = true
                premiumLocked = true
                onPremiumRequired?()
                let message = HiAirL10n.t("planner.premium_required", lang: language)
                activitySurface = .premiumLocked(message: message)
                activityStatusText = message
            } else {
                let message = activityFailureMessage(language: language, forecastLoaded: hasForecastData)
                activitySurface = .failed(message: message)
                activityStatusText = message
            }
            activityPlan = nil
        } catch {
            ProductAnalytics.track(
                "activity_plan_fetch_failed",
                properties: ["activity": selectedActivity]
            )
            let message = activityFailureMessage(language: language, forecastLoaded: hasForecastData)
            activitySurface = .failed(message: message)
            activityStatusText = message
            activityPlan = nil
        }
    }

    func activityFailureMessage(language: String, forecastLoaded: Bool) -> String {
        if forecastLoaded {
            return HiAirL10n.t("planner.activity.forecast_unavailable", lang: language)
        }
        return HiAirL10n.t("planner.empty.unavailable.body", lang: language)
    }

    func markActivityPlanned(
        profileId: String,
        userId: String,
        accessToken: String,
        language: String,
        onPremiumRequired: (() -> Void)? = nil
    ) async {
        await recordProtectedDayEvent(
            profileId: profileId,
            userId: userId,
            accessToken: accessToken,
            language: language,
            eventType: "workout_moved",
            successKey: "planner.activity.mark_planned_done",
            analyticsEvent: "activity_plan_marked_planned",
            onPremiumRequired: onPremiumRequired
        ) { [weak self] status in
            self?.activityPlanMarked = true
            self?.activityPlanMarkStatus = status
        } onFailure: { [weak self] status in
            self?.activityPlanMarkStatus = status
        }
    }

    func markVentilationUsed(
        profileId: String,
        userId: String,
        accessToken: String,
        language: String,
        onPremiumRequired: (() -> Void)? = nil
    ) async {
        await recordProtectedDayEvent(
            profileId: profileId,
            userId: userId,
            accessToken: accessToken,
            language: language,
            eventType: "ventilation_window_used",
            successKey: "planner.ventilation.mark_done",
            analyticsEvent: "ventilation_window_marked_used",
            onPremiumRequired: onPremiumRequired
        ) { [weak self] status in
            self?.ventilationWindowMarked = true
            self?.ventilationMarkStatus = status
        } onFailure: { [weak self] status in
            self?.ventilationMarkStatus = status
        }
    }

    private func recordProtectedDayEvent(
        profileId: String,
        userId: String,
        accessToken: String,
        language: String,
        eventType: String,
        successKey: String,
        analyticsEvent: String,
        onPremiumRequired: (() -> Void)?,
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
            ProductAnalytics.track(analyticsEvent)
            ProductAnalytics.track(
                "protected_day_event_recorded",
                properties: ["event_type": eventType]
            )
            if eventType == "workout_moved" {
                ProductAnalytics.track("activity_plan_followed", properties: ["event_type": eventType])
            }
        } catch let error as APIError {
            let premiumCode: Int? = {
                if case .server(let code) = error { return code }
                if case .serverWithDetail(let code, _) = error { return code }
                return nil
            }()
            if premiumCode == 402 {
                activityPremiumLocked = true
                onPremiumRequired?()
                onFailure(HiAirL10n.t("planner.premium_required", lang: language))
            } else {
                onFailure(HiAirL10n.t("planner.activity.mark_planned_failed", lang: language))
            }
        } catch {
            onFailure(HiAirL10n.t("planner.activity.mark_planned_failed", lang: language))
        }
    }

    func selectActivity(
        _ activity: String,
        profileId: String,
        userId: String,
        accessToken: String,
        language: String,
        onPremiumRequired: (() -> Void)? = nil
    ) {
        selectedActivity = activity
        Task {
            await refreshActivityPlan(
                profileId: profileId,
                userId: userId,
                accessToken: accessToken,
                language: language,
                onPremiumRequired: onPremiumRequired
            )
        }
    }

    private static let fallbackActivities: [ActivityCatalogItem] = [
        ActivityCatalogItem(activity: "running", defaultDurationMinutes: 45, defaultIntensity: "high", outdoor: true),
        ActivityCatalogItem(activity: "walking", defaultDurationMinutes: 30, defaultIntensity: "low", outdoor: true),
        ActivityCatalogItem(activity: "cycling", defaultDurationMinutes: 60, defaultIntensity: "moderate", outdoor: true),
        ActivityCatalogItem(activity: "hiking", defaultDurationMinutes: 90, defaultIntensity: "moderate", outdoor: true),
        ActivityCatalogItem(activity: "dog_walk", defaultDurationMinutes: 30, defaultIntensity: "low", outdoor: true),
        ActivityCatalogItem(activity: "playground", defaultDurationMinutes: 60, defaultIntensity: "low", outdoor: true),
        ActivityCatalogItem(activity: "outdoor_sport", defaultDurationMinutes: 60, defaultIntensity: "high", outdoor: true),
        ActivityCatalogItem(activity: "beach", defaultDurationMinutes: 120, defaultIntensity: "moderate", outdoor: true),
        ActivityCatalogItem(activity: "outdoor_work", defaultDurationMinutes: 120, defaultIntensity: "moderate", outdoor: true),
        ActivityCatalogItem(activity: "ventilation", defaultDurationMinutes: 60, defaultIntensity: "low", outdoor: false),
    ]

    static var fallbackActivitiesForUI: [ActivityCatalogItem] { fallbackActivities }
}

struct DailyPlannerView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = DailyPlannerViewModel()
    @State private var selectedDate = Date()

    var body: some View {
        HiAirAdaptiveLayout { width, mode in
            ScrollView {
                VStack(alignment: .leading, spacing: HiAirResponsiveSpacing.sectionSpacing(for: mode)) {
                HStack(alignment: .center) {
                    HiAirScreenWordmark(suffix: plannerSuffix)
                    Button {
                        session.showPaywall = viewModel.premiumLocked
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(HiAirColors.Text.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(session.l("planner.subtitle"))
                }

                HiAirDateStrip(selected: selectedDate) { selectedDate = $0 }

                if let banner = viewModel.forecastSurface.bannerMessage,
                   !viewModel.hasForecastData {
                    Text(banner)
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirColors.Text.secondary)
                        .accessibilityIdentifier(HiAirAccessibilityID.Planner.status)
                }
                if !viewModel.freshness.isEmpty && viewModel.forecastAvailable {
                    Text(freshnessCaption)
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirColors.Text.tertiary)
                }
                if !viewModel.sources.isEmpty && viewModel.forecastAvailable {
                    Text("\(session.l("planner.sources")): \(viewModel.sources.joined(separator: ", "))")
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirColors.Text.tertiary)
                }

                if !session.profileId.isEmpty {
                    activityBestTimeCard
                }

                if viewModel.premiumLocked {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(session.l("planner.premium_locked.title"))
                            .font(AuroraTokens.Typography.titleMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        Text(session.l("planner.premium_required"))
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                        Button(session.l("insights.premium_locked.cta")) {
                            session.showPaywall = true
                        }
                        .buttonStyle(HiAirGradientButtonStyle())
                    }
                    .v2Card()
                }

                if session.profileId.isEmpty {
                    ProfileBootstrapCard(
                        titleKey: "planner.empty.no_profile.title",
                        bodyKey: "planner.empty.no_profile.body",
                        ctaKey: "planner.empty.no_profile.cta",
                        ctaAccessibilityID: HiAirAccessibilityID.Planner.createProfileCTA,
                        usePrimaryStyle: false,
                        onReady: {
                            await viewModel.refresh(
                                profileId: session.profileId,
                                userId: session.userId,
                                accessToken: session.accessToken,
                                language: session.preferredLanguage,
                                onPremiumRequired: { session.showPaywall = true }
                            )
                        }
                    )
                }

                if !viewModel.hourlyItems.isEmpty || !viewModel.safeWindows.isEmpty {
                    plannerLiveContent
                }

                Button(viewModel.loading ? session.l("planner.loading") : session.l("planner.refresh")) {
                    Task {
                        if session.profileId.isEmpty {
                            // Explicit user refresh — do not reuse a prior terminal ensure failure.
                            session.beginExplicitProfileEnsureCycle()
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
                            language: session.preferredLanguage,
                            onPremiumRequired: { session.showPaywall = true }
                        )
                        session.markChecklistItem("hourly", done: true)
                    }
                }
                .buttonStyle(HiAirGradientButtonStyle())
                .disabled(viewModel.loading)
                .accessibilityIdentifier(HiAirAccessibilityID.Planner.refresh)

                Button(session.l("planner.apply")) {
                    session.selectedTab = 0
                }
                .buttonStyle(HiAirSecondaryButtonStyle())
            }
            .hiAirContentWidth(for: width)
            .hiAirScreenPadding(for: width)
                .hiAirMainTabScrollContent()
            }
        }
        .hiAirPageBackground()
        .task {
            if UITestBootstrap.disableAutoProfileBootstrap {
                if session.profileId.isEmpty {
                    viewModel.statusText = session.l("planner.profile_required")
                }
                return
            }
            if !session.hasValidLocation {
                _ = await session.bootstrapLocationFromDevice()
            }
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
                language: session.preferredLanguage,
                onPremiumRequired: { session.showPaywall = true }
            )
            session.markChecklistItem("hourly", done: true)
        }
        .onChange(of: session.locationRevision) { _ in
            Task {
                guard !session.profileId.isEmpty else { return }
                await viewModel.refresh(
                    profileId: session.profileId,
                    userId: session.userId,
                    accessToken: session.accessToken,
                    language: session.preferredLanguage,
                    onPremiumRequired: { session.showPaywall = true }
                )
            }
        }
    }

    private var plannerSuffix: String {
        let title = dg("planner.title")
        if title.hasPrefix("HiAir ") {
            return String(title.dropFirst(6))
        }
        return session.l("tab.planner")
    }

    private func dg(_ key: String) -> String {
        HiAirDeepGlassCopy.t(key, lang: session.preferredLanguage)
    }

    @ViewBuilder
    private var plannerLiveContent: some View {
        HiAirPlannerSummaryStrip(
            riskLabel: localizedRisk(peakRisk),
            riskLevel: peakRisk,
            outdoorRange: outdoorRangeText,
            outdoorHint: dg("low_pollution_uv"),
            ventilationRange: ventilationRangeText,
            ventilationHint: dg("ventilate_hint"),
            lang: session.preferredLanguage
        )

        if !viewModel.hourlyItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(dg("chart_24h").uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HiAirColors.Text.secondary)
                    Spacer()
                    Text(dg("aqi_us"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(HiAirColors.Text.tertiary)
                }
                HiAirHourlyRiskChart(
                    points: viewModel.hourlyItems,
                    highlightStartHour: HiAirDeepGlassTime.hour(from: viewModel.safeWindows.first?.start ?? ""),
                    highlightEndHour: HiAirDeepGlassTime.hour(from: viewModel.safeWindows.first?.end ?? "")
                )
                if let first = viewModel.safeWindows.first {
                    Text("\(dg("recommended")): \(humanWindowRange(first.start, first.end))")
                        .font(HiAirTypography.caption.weight(.semibold))
                        .foregroundStyle(HiAirColors.Spectrum.cyan)
                }
                if !viewModel.ventilationWindows.isEmpty {
                    if !viewModel.ventilationWindowMarked {
                        Button(session.l("planner.ventilation.mark_used")) {
                            Task {
                                await viewModel.markVentilationUsed(
                                    profileId: session.profileId,
                                    userId: session.userId,
                                    accessToken: session.accessToken,
                                    language: session.preferredLanguage,
                                    onPremiumRequired: { session.showPaywall = true }
                                )
                            }
                        }
                        .buttonStyle(HiAirOutlineCTAButtonStyle())
                    }
                    if !viewModel.ventilationMarkStatus.isEmpty {
                        Text(viewModel.ventilationMarkStatus)
                            .font(HiAirTypography.caption)
                            .foregroundStyle(HiAirColors.Text.secondary)
                    }
                }
            }
            .padding(HiAirSpacing.md)
            .hiAirGlassSurface(prominence: .hero, glow: HiAirColors.Spectrum.cyan)
        }

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(dayParts, id: \.title) { part in
                    HiAirDayPartCard(
                        title: part.title,
                        hours: part.hours,
                        temperature: "",
                        aqi: localizedRisk(part.risk),
                        risk: part.risk,
                        bodyText: part.body,
                        iconName: part.icon
                    )
                    .frame(width: 148, alignment: .topLeading)
                    .frame(minHeight: 176)
                }
            }
        }

        Text(dg("recommendations").uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(HiAirColors.Text.secondary)

        HStack(spacing: 10) {
            HiAirActionHintCard(
                title: dg("ventilation"),
                value: ventilationRangeText,
                bodyText: dg("optimal_ventilate"),
                icon: "wind",
                action: { session.selectedTab = 0 }
            )
            HiAirActionHintCard(
                title: dg("hydration"),
                value: dg("hydrate_goal_l"),
                bodyText: dg("hydrate_goal"),
                icon: "drop.fill",
                action: { session.selectedTab = 3 }
            )
        }
    }

    private var peakRisk: String {
        viewModel.hourlyItems.max(by: { riskWeight($0.overallRisk) < riskWeight($1.overallRisk) })?.overallRisk
            ?? viewModel.hourlyItems.first?.overallRisk
            ?? "moderate"
    }

    private var outdoorRangeText: String {
        if let first = viewModel.safeWindows.first {
            return humanWindowRange(first.start, first.end)
        }
        return session.l("common.unavailable")
    }

    private var ventilationRangeText: String {
        if let first = viewModel.ventilationWindows.first {
            return humanWindowRange(first.start, first.end)
        }
        return session.l("common.unavailable")
    }

    private struct DayPart: Identifiable {
        var id: String { title }
        let title: String
        let hours: String
        let risk: String
        let body: String
        let icon: String
    }

    private var dayParts: [DayPart] {
        [
            bucket(title: dg("morning"), hours: "06:00–12:00", icon: "sunrise.fill", range: 6..<12, body: dg("low_pollution")),
            bucket(title: dg("day"), hours: "12:00–18:00", icon: "sun.max.fill", range: 12..<18, body: session.l("planner.hourly")),
            bucket(title: dg("evening"), hours: "18:00–22:00", icon: "sunset.fill", range: 18..<22, body: dg("ventilate_hint")),
            bucket(title: dg("night"), hours: "22:00–06:00", icon: "moon.stars.fill", range: nil, body: dg("low_pollution")),
        ]
    }

    private func bucket(title: String, hours: String, icon: String, range: Range<Int>?, body: String) -> DayPart {
        let items: [AirHourlyRiskPoint]
        if let range {
            items = viewModel.hourlyItems.filter { point in
                guard let hour = HiAirDeepGlassTime.hour(from: point.hour) else { return false }
                return range.contains(hour)
            }
        } else {
            items = viewModel.hourlyItems.filter { point in
                guard let hour = HiAirDeepGlassTime.hour(from: point.hour) else { return false }
                return hour >= 22 || hour < 6
            }
        }
        let risk = items.max(by: { riskWeight($0.overallRisk) < riskWeight($1.overallRisk) })?.overallRisk ?? "low"
        return DayPart(title: title, hours: hours, risk: risk, body: body, icon: icon)
    }

    private func localizedRisk(_ risk: String) -> String {
        switch risk.lowercased() {
        case "low":
            return dg("spectrum.low")
        case "moderate", "medium":
            return dg("spectrum.moderate")
        case "high":
            return dg("spectrum.high")
        case "very_high", "very high":
            return dg("spectrum.very_high")
        default:
            return dg("spectrum.moderate")
        }
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

    private var activityBestTimeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l("planner.activity.title"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            Text(session.l("planner.activity.subtitle"))
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)

            if viewModel.activityPremiumLocked {
                Text(session.l("planner.premium_required"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
                Button(session.l("insights.premium_locked.cta")) {
                    session.showPaywall = true
                }
                .buttonStyle(HiAirGradientButtonStyle())
            } else {
                Picker(session.l("planner.activity.picker"), selection: $viewModel.selectedActivity) {
                    ForEach(viewModel.activities.isEmpty ? DailyPlannerViewModel.fallbackActivitiesForUI : viewModel.activities) { item in
                        Text(session.l("planner.activity.\(item.activity)")).tag(item.activity)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.selectedActivity) { newValue in
                    viewModel.selectActivity(
                        newValue,
                        profileId: session.profileId,
                        userId: session.userId,
                        accessToken: session.accessToken,
                        language: session.preferredLanguage,
                        onPremiumRequired: { session.showPaywall = true }
                    )
                }

                if !viewModel.savedPlaces.isEmpty {
                    Picker(session.l("planner.activity.place"), selection: Binding(
                        get: { viewModel.selectedPlaceId ?? "" },
                        set: { viewModel.selectedPlaceId = $0.isEmpty ? nil : $0 }
                    )) {
                        Text(session.l("planner.activity.place_home")).tag("")
                        ForEach(viewModel.savedPlaces) { place in
                            Text(place.name).tag(place.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.selectedPlaceId) { _ in
                        Task {
                            await viewModel.refreshActivityPlan(
                                profileId: session.profileId,
                                userId: session.userId,
                                accessToken: session.accessToken,
                                language: session.preferredLanguage,
                                onPremiumRequired: { session.showPaywall = true }
                            )
                        }
                    }
                }

                if viewModel.activityPlanLoading {
                    Text(session.l("planner.activity.loading"))
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                } else if let inline = viewModel.activitySurface.inlineMessage,
                          !viewModel.activitySurface.hasDisplayableData {
                    Text(inline)
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                }

                if let recommended = viewModel.activityPlan?.recommendedStart,
                   viewModel.activityPlan?.isForecastAvailable == true {
                    Text(
                        String(
                            format: session.l("planner.activity.recommended"),
                            humanActivityTime(recommended)
                        )
                    )
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                }

                if let plan = viewModel.activityPlan, plan.isForecastAvailable, !plan.windows.isEmpty {
                    if !viewModel.activityPlanMarked {
                        Button(session.l("planner.activity.mark_planned")) {
                            Task {
                                await viewModel.markActivityPlanned(
                                    profileId: session.profileId,
                                    userId: session.userId,
                                    accessToken: session.accessToken,
                                    language: session.preferredLanguage,
                                    onPremiumRequired: { session.showPaywall = true }
                                )
                            }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                        .accessibilityIdentifier(HiAirAccessibilityID.Planner.markActivityPlanned)
                    }
                    if !viewModel.activityPlanMarkStatus.isEmpty {
                        Text(viewModel.activityPlanMarkStatus)
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(sortedActivityWindows(plan.windows)) { window in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(tierColor(window.tier))
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 6)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(localizedTier(window.tier)): \(humanActivityWindowRange(window.start, window.end))")
                                        .font(AuroraTokens.Typography.bodyMD)
                                        .foregroundStyle(HiAirV2Theme.primaryText)
                                    if !window.reasonCodes.isEmpty {
                                        Text(localizedReasonCodes(window.reasonCodes))
                                            .font(AuroraTokens.Typography.caption)
                                            .foregroundStyle(HiAirV2Theme.tertiaryText)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .v2Card()
    }

    private func sortedActivityWindows(_ windows: [ActivityWindow]) -> [ActivityWindow] {
        windows.sorted { lhs, rhs in
            let order = tierSortOrder(lhs.tier) - tierSortOrder(rhs.tier)
            if order != 0 { return order < 0 }
            return lhs.start < rhs.start
        }
    }

    private func tierSortOrder(_ tier: String) -> Int {
        switch tier.lowercased() {
        case "best": return 0
        case "acceptable": return 1
        case "avoid": return 2
        default: return 3
        }
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier.lowercased() {
        case "best":
            return RiskAccentColor.color(for: "low")
        case "acceptable":
            return RiskAccentColor.color(for: "moderate")
        case "avoid":
            return RiskAccentColor.color(for: "high")
        default:
            return HiAirV2Theme.tertiaryText
        }
    }

    private func localizedTier(_ tier: String) -> String {
        switch tier.lowercased() {
        case "best":
            return session.l("planner.activity.tier.best")
        case "acceptable":
            return session.l("planner.activity.tier.acceptable")
        case "avoid":
            return session.l("planner.activity.tier.avoid")
        default:
            return tier
        }
    }

    private func localizedReasonCodes(_ codes: [String]) -> String {
        codes.prefix(3).map { code in
            let key = "planner.activity.reason.\(code)"
            let localized = session.l(key)
            return localized == key ? code : localized
        }.joined(separator: " · ")
    }

    private func humanActivityTime(_ raw: String) -> String {
        HiAirHumanDate.string(
            fromISO: raw,
            locale: Locale(identifier: session.preferredLanguage),
            style: .time,
            timeZone: HiAirHumanDate.timeZone(identifier: activityTimezone)
        ) ?? session.l("common.unavailable")
    }

    private func humanActivityWindowRange(_ start: String, _ end: String) -> String {
        HiAirHumanDate.timeRange(
            fromISO: start,
            toISO: end,
            locale: Locale(identifier: session.preferredLanguage),
            timeZone: HiAirHumanDate.timeZone(identifier: activityTimezone),
            unavailable: session.l("common.unavailable")
        )
    }

    private var activityTimezone: String {
        let planTz = viewModel.activityTimezoneIdentifier
        if !planTz.isEmpty { return planTz }
        return viewModel.timezoneIdentifier
    }

    private var freshnessCaption: String {
        switch viewModel.freshness.lowercased() {
        case "cached":
            return session.l("planner.freshness.cached")
        case "stale":
            return session.l("planner.freshness.stale")
        default:
            return session.l("planner.freshness.live")
        }
    }

    private func color(for risk: String) -> Color {
        RiskAccentColor.color(for: risk)
    }

    private func keyEventLine() -> String {
        guard let maxRisk = viewModel.hourlyItems.max(by: { riskWeight($0.overallRisk) < riskWeight($1.overallRisk) }) else {
            return session.l("planner.fetch")
        }
        let riskLabel = localizedRisk(maxRisk.overallRisk)
        let hourLabel = humanHour(maxRisk.hour)
        return String(format: session.l("planner.peak_line"), riskLabel, hourLabel)
    }

    private func localizedWindowType(_ type: String) -> String {
        switch type.lowercased() {
        case "ventilation", "ventilate":
            return session.l("planner.window.ventilation")
        case "walk", "outdoor", "safe", "sport", "exercise", "run":
            return session.l("planner.window.safe")
        default:
            return session.l("dashboard.safe_window")
        }
    }

    private func humanWindowRange(_ start: String, _ end: String) -> String {
        HiAirHumanDate.timeRange(
            fromISO: start,
            toISO: end,
            locale: Locale(identifier: session.preferredLanguage),
            timeZone: HiAirHumanDate.timeZone(identifier: viewModel.timezoneIdentifier),
            unavailable: session.l("common.unavailable")
        )
    }

    private func humanHour(_ raw: String) -> String {
        let zone = HiAirHumanDate.timeZone(identifier: viewModel.timezoneIdentifier)
        if let date = HiAirHumanDate.date(fromISO: raw) {
            return HiAirHumanDate.string(
                from: date,
                locale: Locale(identifier: session.preferredLanguage),
                style: .time,
                timeZone: zone
            )
        }
        // Hourly slots may be "14:00" or "14"
        if raw.count >= 2, raw.prefix(2).allSatisfy(\.isNumber) {
            return String(raw.prefix(5))
        }
        return raw
    }
}
