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
        } catch let error as APIError {
            ProductAnalytics.track("forecast_fetch_failed", properties: ["surface": "planner"])
            let premiumCode: Int? = {
                if case .server(let code) = error { return code }
                if case .serverWithDetail(let code, _) = error { return code }
                return nil
            }()
            if premiumCode == 402 {
                premiumLocked = true
                onPremiumRequired?()
                statusText = HiAirL10n.t("planner.premium_required", lang: language)
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
