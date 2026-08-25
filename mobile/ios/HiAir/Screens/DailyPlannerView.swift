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

    private let apiClient = APIClient.live()

    func refresh(
        profileId: String,
        userId: String,
        accessToken: String,
        language: String,
        onPremiumRequired: (() -> Void)? = nil
    ) async {
        loading = true
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
                statusText = HiAirL10n.t("planner.forecast_unavailable", lang: language)
                ProductAnalytics.track("planner_forecast_unavailable", properties: ["quality": dataQuality])
            } else if planner.dataQuality == "partial" {
                var partial = HiAirL10n.t("planner.forecast_partial", lang: language)
                if !missingMetrics.isEmpty {
                    let listed = missingMetrics.prefix(4).joined(separator: ", ")
                    partial += " (\(listed))"
                }
                statusText = partial
                ProductAnalytics.track(
                    "planner_real_forecast_loaded",
                    properties: ["quality": "partial", "hours": String(planner.hourlyRisk.count)]
                )
            } else {
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
                statusText = HiAirL10n.t("planner.premium_required", lang: language)
                activityStatusText = HiAirL10n.t("planner.premium_required", lang: language)
            } else {
                statusText = HiAirL10n.t("planner.empty.unavailable.body", lang: language)
            }
            hourlyItems = []
            safeWindows = []
            ventilationWindows = []
            forecastAvailable = false
        } catch {
            ProductAnalytics.track("forecast_fetch_failed", properties: ["surface": "planner"])
            statusText = HiAirL10n.t("planner.empty.unavailable.body", lang: language)
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
            if !plan.isForecastAvailable {
                activityStatusText = HiAirL10n.t("planner.activity.forecast_unavailable", lang: language)
            } else if plan.dataQuality == "partial" {
                activityStatusText = HiAirL10n.t("planner.forecast_partial", lang: language)
            } else if plan.windows.isEmpty {
                activityStatusText = HiAirL10n.t("planner.activity.no_windows", lang: language)
            } else {
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
                activityStatusText = HiAirL10n.t("planner.premium_required", lang: language)
            } else {
                activityStatusText = HiAirL10n.t("planner.empty.unavailable.body", lang: language)
            }
            activityPlan = nil
        } catch {
            ProductAnalytics.track(
                "activity_plan_fetch_failed",
                properties: ["activity": selectedActivity]
            )
            activityStatusText = HiAirL10n.t("planner.empty.unavailable.body", lang: language)
            activityPlan = nil
        }
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

    var body: some View {
        HiAirAdaptiveLayout { width, mode in
            ScrollView {
                VStack(alignment: .leading, spacing: HiAirResponsiveSpacing.sectionSpacing(for: mode)) {
                Text(session.l("planner.title"))
                    .font(AuroraTokens.Typography.displayLG)
                    .foregroundStyle(HiAirV2Theme.primaryText)

                Text(session.l("planner.subtitle"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                if !viewModel.statusText.isEmpty && !viewModel.premiumLocked {
                    Text(viewModel.statusText)
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                }
                if !viewModel.freshness.isEmpty && viewModel.forecastAvailable {
                    Text(freshnessCaption)
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.tertiaryText)
                }
                if !viewModel.sources.isEmpty && viewModel.forecastAvailable {
                    Text("\(session.l("planner.sources")): \(viewModel.sources.joined(separator: ", "))")
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.tertiaryText)
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

                if !viewModel.hourlyItems.isEmpty && viewModel.forecastAvailable {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.l("planner.hourly"))
                            .font(AuroraTokens.Typography.titleMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .bottom, spacing: 3) {
                                ForEach(Array(viewModel.hourlyItems.prefix(24).enumerated()), id: \.offset) { index, item in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(color(for: item.overallRisk))
                                        .frame(width: 4, height: index % 2 == 0 ? 32 : 24)
                                        .overlay(alignment: .bottom) {
                                            if index % 6 == 0 {
                                                Text(humanHour(item.hour))
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
                                .font(AuroraTokens.Typography.bodyMD)
                                .foregroundStyle(HiAirV2Theme.primaryText)
                            if let firstWindow = viewModel.safeWindows.first {
                                Text("• \(localizedWindowType(firstWindow.type)): \(humanWindowRange(firstWindow.start, firstWindow.end))")
                                    .font(AuroraTokens.Typography.bodyMD)
                                    .foregroundStyle(HiAirV2Theme.secondaryText)
                            }
                            if let firstVent = viewModel.ventilationWindows.first {
                                Text("• \(session.l("planner.ventilation_windows")): \(humanWindowRange(firstVent.start, firstVent.end))")
                                    .font(AuroraTokens.Typography.bodyMD)
                                    .foregroundStyle(HiAirV2Theme.secondaryText)
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
                                    .buttonStyle(HiAirSecondaryButtonStyle())
                                }
                                if !viewModel.ventilationMarkStatus.isEmpty {
                                    Text(viewModel.ventilationMarkStatus)
                                        .font(AuroraTokens.Typography.caption)
                                        .foregroundStyle(HiAirV2Theme.secondaryText)
                                }
                            }
                        }
                    }
                    .v2Card()
                } else if !viewModel.safeWindows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.l("planner.safe_windows"))
                            .font(AuroraTokens.Typography.titleMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        ForEach(viewModel.safeWindows, id: \.start) { window in
                            Text("\(localizedWindowType(window.type)): \(humanWindowRange(window.start, window.end))")
                                .font(AuroraTokens.Typography.bodyMD)
                                .foregroundStyle(HiAirV2Theme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(HiAirColors.Overlay.subtle, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .v2Card()
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

                Button(session.l("planner.apply")) {
                    session.selectedTab = 0
                }
                .buttonStyle(HiAirSecondaryButtonStyle())
            }
            .hiAirContentWidth(for: width)
            .hiAirScreenPadding(for: width)
            .padding(.bottom, HiAirSpacing.xl)
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
        .onReceive(NotificationCenter.default.publisher(for: .hiairTravelSessionDidChange)) { _ in
            session.locationRevision += 1
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
                } else if !viewModel.activityStatusText.isEmpty {
                    Text(viewModel.activityStatusText)
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

    private func localizedRisk(_ risk: String) -> String {
        switch risk.lowercased() {
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
