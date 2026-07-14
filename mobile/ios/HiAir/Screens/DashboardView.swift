import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var loading = false
    @Published var riskLevel = "-"
    @Published var explanation = "-"
    @Published var headline = "-"
    @Published var actions: [String] = []
    @Published var nearestSafeWindow = "-"
    @Published var safeWindowLabels: [String] = []
    @Published var environmental: AirEnvironmentalInput?
    @Published var wearableToday: WearableTodayResponse?
    @Published var wearableConnectionState: WearableConnectionState = .notConnected

    private let apiClient = APIClient.live()
    private let healthService = HealthKitService.shared

    func refresh(
        userId: String,
        accessToken: String,
        profileId: String?,
        language: String
    ) async {
        loading = true
        defer { loading = false }
        guard let profileId, !profileId.isEmpty else {
            riskLevel = "unknown"
            headline = HiAirL10n.t("dashboard.empty.no_profile.title", lang: language)
            explanation = HiAirL10n.t("dashboard.empty.no_profile.body", lang: language)
            actions = []
            nearestSafeWindow = "-"
            safeWindowLabels = []
            environmental = nil
            wearableToday = nil
            return
        }
        do {
            async let riskTask = apiClient.fetchCurrentRisk(
                profileId: profileId,
                userId: userId,
                accessToken: accessToken
            )
            async let wearableTask = apiClient.fetchWearableToday(userId: userId, accessToken: accessToken)
            let result = try await riskTask
            wearableToday = try? await wearableTask
            wearableConnectionState = healthService.refreshAuthorizationState()
            riskLevel = result.risk.overallRisk
            explanation = result.explanation
            headline = result.recommendation.headline
            actions = result.recommendation.actions
            environmental = result.environmental
            safeWindowLabels = result.risk.safeWindows.map {
                "\($0.type): \($0.start) -> \($0.end)"
            }
            if let firstWindow = result.risk.safeWindows.first {
                nearestSafeWindow = "\(firstWindow.type): \(firstWindow.start) -> \(firstWindow.end)"
            } else {
                nearestSafeWindow = HiAirL10n.t("dashboard.no_safe_window", lang: language)
            }
        } catch {
            riskLevel = "error"
            headline = HiAirL10n.t("dashboard.error", lang: language)
            explanation = HiAirL10n.t("dashboard.empty.api_unavailable", lang: language)
            actions = []
            nearestSafeWindow = "-"
            safeWindowLabels = []
            environmental = nil
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var healthService = HealthKitService.shared
    @StateObject private var locationService = LocationService.shared
    @State private var activeInfoKey: InfoTerm?
    @State private var showWearableConsent = false

    private var riskScore: Int {
        switch viewModel.riskLevel.lowercased() {
        case "low":
            return 24
        case "moderate", "medium":
            return 58
        case "high":
            return 79
        case "very_high", "very high":
            return 90
        default:
            return 58
        }
    }

    private var riskColor: Color {
        RiskAccentColor.color(for: viewModel.riskLevel)
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

    private var pm25Estimate: Double {
        if let pm25 = viewModel.environmental?.pm25 {
            return pm25
        }
        switch viewModel.riskLevel.lowercased() {
        case "low":
            return 12
        case "moderate", "medium":
            return 32
        case "high":
            return 52
        case "very_high", "very high":
            return 85
        default:
            return 25
        }
    }

    private var freshnessLabel: String {
        viewModel.loading ? session.l("dashboard.freshness_stale") : session.l("dashboard.freshness_fresh")
    }

    private var safeWindows: [String] {
        viewModel.safeWindowLabels
    }

    private var locationLabel: String {
        if session.hasValidLocation {
            return session.l("dashboard.location")
        }
        return session.l("dashboard.location_unknown")
    }

    private func reloadDashboard() async {
        if session.profileId.isEmpty {
            _ = await session.ensureProfileIdIfNeeded()
        }
        await viewModel.refresh(
            userId: session.userId,
            accessToken: session.accessToken,
            profileId: session.profileId.isEmpty ? nil : session.profileId,
            language: session.preferredLanguage
        )
    }

    private var riskReason: String {
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

    var body: some View {
        HiAirAdaptiveLayout { width, mode in
            ScrollView {
                VStack(alignment: .leading, spacing: HiAirResponsiveSpacing.sectionSpacing(for: mode)) {
                    dashboardHeader
                    greetingSection
                    checklistSection
                    emptyStateSections
                    riskHeroSection(width: width)
                    wearableLoadSection
                    weatherSection(width: width)
                    environmentalSection
                    recommendationsSection
                    safeWindowsSection
                    actionButtons
                }
                .hiAirContentWidth(for: width)
                .hiAirScreenPadding(for: width)
                .padding(.bottom, HiAirSpacing.xl)
            }
        }
        .hiAirPageBackground()
        .overlay(
            AtmosphericParticles(pm25: pm25Estimate, tint: riskColor)
                .allowsHitTesting(false)
        )
        .task {
            ProductAnalytics.track("dashboard_opened")
            if !session.hasValidLocation {
                _ = await session.bootstrapLocationFromDevice(locationService: locationService)
            }
            await reloadDashboard()
            session.markChecklistItem("risk", done: true)
        }
        .onChange(of: session.locationRevision) { _ in
            Task { await reloadDashboard() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileLocationDidUpdate)) { _ in
            Task { await reloadDashboard() }
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

        Text(session.l("dashboard.greeting_neutral"))
            .font(HiAirTypography.displayLG)
            .foregroundStyle(HiAirV2Theme.primaryText)

        Text(session.l("dashboard.improving_neutral"))
            .font(HiAirTypography.bodyMD)
            .foregroundStyle(HiAirV2Theme.secondaryText)
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
            VStack(alignment: .leading, spacing: 8) {
                Text(session.l("dashboard.empty.no_profile.title"))
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                Text(session.l("dashboard.empty.no_profile.body"))
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
                Button(session.l("dashboard.empty.no_profile.cta")) {
                    Task {
                        let created = await session.ensureProfileIdIfNeeded()
                        if created {
                            session.markChecklistItem("profile", done: true)
                        }
                    }
                }
                .buttonStyle(HiAirGradientButtonStyle())
            }
            .v2Card()
        }
    }

    @ViewBuilder
    private func riskHeroSection(width: CGFloat) -> some View {
        HiAirCard {
            HiAirRiskGaugeView(
                score: riskScore,
                sectionLabel: session.l("dashboard.current_risk_title"),
                statusLabel: moodTitle,
                riskLevel: viewModel.riskLevel == "-" ? "moderate" : viewModel.riskLevel,
                reason: riskReason,
                diameter: min(width * 0.52, 220)
            )
        }
    }

    @ViewBuilder
    private func weatherSection(width: CGFloat) -> some View {
        HStack(spacing: 12) {
            HiAirOrbLogoView(
                size: HiAirScreenMetrics.heroOrbSize(for: width),
                riskLevel: viewModel.riskLevel,
                presentation: .brand
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(weatherTitle)
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                Text("\(session.l("dashboard.mood_prefix")): \(moodTitle)")
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
                Text(session.l("dashboard.auto_updates"))
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirV2Theme.tertiaryText)
            }
            Spacer()
        }
        .padding(10)
        .v2Card()
    }

    @ViewBuilder
    private var environmentalSection: some View {
        if let env = viewModel.environmental {
            VStack(alignment: .leading, spacing: 8) {
                Text(session.l("dashboard.air_metrics"))
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                Text(session.l(sourceLabelKey(for: env.source)))
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirV2Theme.tertiaryText)
                metricRow("dashboard.metric.aqi", value: "\(env.aqi)", tooltip: "dashboard.tooltip.aqi")
                metricRow("dashboard.metric.pm25", value: String(format: "%.1f", env.pm25), tooltip: "dashboard.tooltip.pm25")
                metricRow("dashboard.metric.ozone", value: String(format: "%.1f", env.ozone), tooltip: "dashboard.tooltip.ozone")
                metricRow("dashboard.metric.heat_index", value: String(format: "%.1f°C", env.feelsLike), tooltip: "dashboard.tooltip.heat_index")
                metricRow("dashboard.metric.humidity", value: String(format: "%.0f%%", env.humidity), tooltip: "dashboard.tooltip.heat_index")
            }
            .v2Card()
            .onAppear {
                ProductAnalytics.track("risk_breakdown_viewed")
            }
        } else if !viewModel.loading {
            Text(session.l("dashboard.empty.api_unavailable"))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
                .v2Card()
        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(session.l("dashboard.do_now"))
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                infoButton("dashboard.recommendations_tooltip")
            }

            if viewModel.actions.isEmpty {
                Text(session.l("dashboard.no_actions"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
            } else {
                ForEach(Array(viewModel.actions.enumerated()), id: \.offset) { index, action in
                    actionTile(
                        icon: index == 0 ? "drop.fill" : (index == 1 ? "wind" : "figure.walk"),
                        text: action
                    )
                }
            }
        }
        .v2Card()
    }

    @ViewBuilder
    private var safeWindowsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.l("dashboard.safe_windows"))
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                infoButton("dashboard.safe_windows_tooltip")
            }
            if safeWindows.isEmpty {
                Text(session.l("dashboard.no_safe_windows"))
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(safeWindows, id: \.self) { window in
                            Text(window)
                                .font(HiAirTypography.caption)
                                .foregroundStyle(HiAirV2Theme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .hiAirChipSurface()
                        }
                    }
                }
            }
        }
        .v2Card()
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(viewModel.loading ? session.l("dashboard.loading") : session.l("dashboard.recompute")) {
            Task {
                if session.profileId.isEmpty {
                    _ = await session.ensureProfileIdIfNeeded()
                }
                session.markChecklistItem("risk", done: true)
                await viewModel.refresh(
                    userId: session.userId,
                    accessToken: session.accessToken,
                    profileId: session.profileId.isEmpty ? nil : session.profileId,
                    language: session.preferredLanguage
                )
            }
        }
        .buttonStyle(HiAirGradientButtonStyle())

        Button(session.l("dashboard.log_symptoms")) {
            session.selectedTab = 3
            session.markChecklistItem("recommendations", done: true)
        }
        .buttonStyle(HiAirSecondaryButtonStyle())
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
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
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
                .foregroundStyle(HiAirV2Theme.tertiaryText)
        }
        .buttonStyle(.plain)
    }

    private func sourceLabelKey(for source: String) -> String {
        switch source.lowercased() {
        case "live":
            return "dashboard.source_live"
        case "cached":
            return "dashboard.source_cached"
        default:
            return "dashboard.source_sample"
        }
    }

    private func metricRow(_ titleKey: String, value: String, tooltip: String) -> some View {
        HStack {
            Text(session.l(titleKey))
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            infoButton(tooltip)
            Spacer()
            Text(value)
                .font(AuroraTokens.Typography.bodyMD.weight(.semibold))
                .foregroundStyle(HiAirV2Theme.primaryText)
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
            VStack(alignment: .leading, spacing: 12) {
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(16)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(closeTitle) { dismiss() }
                }
            }
        }
    }
}

