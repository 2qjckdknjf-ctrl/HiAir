import SwiftUI
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    enum AIChartMetric: String, CaseIterable, Identifiable {
        case total
        case fallback
        case guardrail
        case errors
        case timeout
        case network
        case server

        var id: String { rawValue }

        var title: String {
            switch self {
            case .total: return "settings.metric.total"
            case .fallback: return "settings.metric.fallback"
            case .guardrail: return "settings.metric.guardrail"
            case .errors: return "settings.metric.errors"
            case .timeout: return "settings.metric.timeout"
            case .network: return "settings.metric.network"
            case .server: return "settings.metric.server"
            }
        }
    }

    enum AIChartMode: String, CaseIterable, Identifiable {
        case bars
        case line

        var id: String { rawValue }

        var title: String {
            switch self {
            case .bars: return "settings.mode.bars"
            case .line: return "settings.mode.line"
            }
        }
    }

    @Published var userId = ""
    @Published var accessToken = ""
    @Published var pushAlertsEnabled = true
    @Published var riskThreshold = "high"
    @Published var quietHoursStart = 22
    @Published var quietHoursEnd = 7
    @Published var profileBasedAlerting = true
    @Published var pushRegistrationStatus = "-"
    @Published var selectedPersona = "adult"
    @Published var preferredLanguage = "ru"
    @Published var plans: [SubscriptionPlan] = []
    @Published var selectedPlanId = "basic_monthly"
    @Published var subscriptionStatus = "inactive"
    @Published var aiSummaryHours = 24
    @Published var aiSummaryText = "-"
    @Published var aiTrendText = "-"
    @Published var aiTrendGraphText = "-" {
        didSet {
            aiRangeText = rangeText(for: currentAiTrendPoints)
        }
    }
    @Published var aiTrendPoints: [Int] = []
    @Published var aiTrendFallbackPoints: [Int] = []
    @Published var aiTrendGuardrailPoints: [Int] = []
    @Published var aiTrendErrorPoints: [Int] = []
    @Published var aiTrendTimeoutPoints: [Int] = []
    @Published var aiTrendNetworkPoints: [Int] = []
    @Published var aiTrendServerPoints: [Int] = []
    @Published var aiChartMetric: AIChartMetric = .total {
        didSet {
            aiTrendGraphText = buildAsciiSparkline(points: currentAiTrendPoints)
            aiRangeText = rangeText(for: currentAiTrendPoints)
        }
    }
    @Published var aiChartMode: AIChartMode = .bars
    @Published var aiRangeText = "-"
    @Published var aiTrendStartLabel = "-"
    @Published var aiTrendEndLabel = "-"
    @Published var aiRequestInFlight = false
    @Published var aiRequestTimedOut = false
    @Published var aiInlineErrorCode: String? = nil
    @Published var aiInlineActionCode: String? = nil
    @Published var aiLastUpdatedLabel = "-"
    @Published var aiBreakdownText = "-"
    @Published var aiTimeoutCount = 0
    @Published var aiNetworkCount = 0
    @Published var aiServerCount = 0
    @Published var aiErrorBreakdown: [AIBreakdownByErrorType] = []
    @Published var statusText = "-"
    @Published var loading = false

    private let apiClient = APIClient.live()
    private var aiRefreshTask: Task<Void, Never>?
    private var aiSummaryRequestVersion: Int = 0
    private var aiTimeoutTask: Task<Void, Never>?

    private func l(_ key: String) -> String {
        HiAirL10n.t(key, lang: preferredLanguage)
    }

    func localizedSubscriptionStatus() -> String {
        switch subscriptionStatus.lowercased() {
        case "active":
            return l("settings.subscription_status_active")
        case "inactive":
            return l("settings.subscription_status_inactive")
        case "canceled", "cancelled":
            return l("settings.subscription_status_canceled")
        default:
            return subscriptionStatus
        }
    }

    private func buildAsciiSparkline(points: [Int]) -> String {
        guard !points.isEmpty else { return "-" }
        let levels = Array(".:-=+*#%@")
        guard let minValue = points.min(), let maxValue = points.max() else { return "-" }
        if maxValue <= minValue {
            return String(repeating: "=", count: points.count)
        }
        let span = Double(maxValue - minValue)
        return points.map { point in
            let normalized = Int((Double(point - minValue) / span) * Double(levels.count - 1))
            let safeIndex = min(max(normalized, 0), levels.count - 1)
            return String(levels[safeIndex])
        }.joined()
    }

    var currentAiTrendPoints: [Int] {
        switch aiChartMetric {
        case .fallback:
            return aiTrendFallbackPoints
        case .guardrail:
            return aiTrendGuardrailPoints
        case .errors:
            return aiTrendErrorPoints
        case .timeout:
            return aiTrendTimeoutPoints
        case .network:
            return aiTrendNetworkPoints
        case .server:
            return aiTrendServerPoints
        case .total:
            return aiTrendPoints
        }
    }

    private func rangeText(for points: [Int]) -> String {
        guard let minValue = points.min(), let maxValue = points.max() else { return "-" }
        return "\(minValue)-\(maxValue)"
    }

    private func hourLabel(_ raw: String) -> String {
        let parts = raw.split(separator: "T")
        let source = parts.count > 1 ? String(parts[1]) : raw
        return String(source.prefix(5))
    }

    func load() async {
        guard !userId.isEmpty else {
            statusText = l("settings.user_id_required")
            return
        }
        loading = true
        defer { loading = false }
        do {
            let response = try await apiClient.fetchUserSettings(userId: userId, accessToken: accessToken)
            pushAlertsEnabled = response.pushAlertsEnabled
            riskThreshold = response.alertThreshold
            selectedPersona = response.defaultPersona
            quietHoursStart = response.quietHoursStart
            quietHoursEnd = response.quietHoursEnd
            profileBasedAlerting = response.profileBasedAlerting
            preferredLanguage = response.preferredLanguage
            statusText = l("settings.loaded")
        } catch {
            statusText = l("settings.load_failed")
        }
    }

    func save() async {
        guard !userId.isEmpty else {
            statusText = l("settings.user_id_required")
            return
        }
        loading = true
        defer { loading = false }
        do {
            _ = try await apiClient.updateUserSettings(
                userId: userId,
                payload: UserSettingsUpdateRequest(
                    pushAlertsEnabled: pushAlertsEnabled,
                    alertThreshold: riskThreshold,
                    defaultPersona: selectedPersona,
                    quietHoursStart: quietHoursStart,
                    quietHoursEnd: quietHoursEnd,
                    profileBasedAlerting: profileBasedAlerting,
                    preferredLanguage: preferredLanguage
                ),
                accessToken: accessToken
            )
            statusText = l("settings.saved")
        } catch {
            statusText = l("settings.save_failed")
        }
    }

    func registerPushDevice() {
        guard !userId.isEmpty, !accessToken.isEmpty else {
            statusText = l("settings.user_id_required")
            pushRegistrationStatus = l("settings.push_registration_missing_auth")
            return
        }
        PushRegistrationService.shared.requestAuthorizationAndRegister()
        let rawStatus = PushRegistrationService.shared.lastRegistrationStatus()
        pushRegistrationStatus = "\(l("settings.push_registration_requested")) \(rawStatus)"
        statusText = l("settings.push_registration_requested")
    }

    func loadPlans() async {
        loading = true
        defer { loading = false }
        do {
            plans = try await apiClient.fetchSubscriptionPlans()
            if let first = plans.first, !plans.contains(where: { $0.planId == selectedPlanId }) {
                selectedPlanId = first.planId
            }
            statusText = l("settings.plans_loaded")
        } catch {
            statusText = l("settings.plans_load_failed")
        }
    }

    func loadSubscription() async {
        guard !userId.isEmpty else {
            statusText = l("settings.user_id_required")
            return
        }
        loading = true
        defer { loading = false }
        do {
            let subscription = try await apiClient.fetchMySubscription(
                userId: userId,
                accessToken: accessToken
            )
            subscriptionStatus = subscription.status
            if let planId = subscription.planId {
                selectedPlanId = planId
            }
            statusText = l("settings.subscription_loaded")
        } catch {
            statusText = l("settings.subscription_load_failed")
        }
    }

    func activateSubscription() async {
        guard !userId.isEmpty else {
            statusText = l("settings.user_id_required")
            return
        }
        loading = true
        defer { loading = false }
        do {
            let subscription = try await apiClient.activateSubscription(
                userId: userId,
                planId: selectedPlanId,
                accessToken: accessToken
            )
            subscriptionStatus = subscription.status
            statusText = l("settings.subscription_activated")
        } catch {
            statusText = l("settings.subscription_activate_failed")
        }
    }

    func cancelSubscription() async {
        guard !userId.isEmpty else {
            statusText = l("settings.user_id_required")
            return
        }
        loading = true
        defer { loading = false }
        do {
            let subscription = try await apiClient.cancelSubscription(
                userId: userId,
                accessToken: accessToken
            )
            subscriptionStatus = subscription.status
            statusText = l("settings.subscription_canceled")
        } catch {
            statusText = l("settings.subscription_cancel_failed")
        }
    }

    func exportPrivacyData() async {
        guard !userId.isEmpty else {
            statusText = l("settings.user_id_required")
            return
        }
        loading = true
        defer { loading = false }
        do {
            let data = try await apiClient.exportPrivacyData(userId: userId, accessToken: accessToken)
            statusText = "\(l("settings.privacy_exported")) \(data.count) bytes"
        } catch {
            statusText = l("settings.privacy_export_failed")
        }
    }

    func deleteAccount(session: AppSession) async {
        guard !userId.isEmpty else {
            statusText = l("settings.user_id_required")
            return
        }
        loading = true
        defer { loading = false }
        do {
            try await apiClient.deleteAccount(userId: userId, accessToken: accessToken)
            statusText = l("settings.account_deleted")
            session.logout()
        } catch {
            statusText = l("settings.account_delete_failed")
        }
    }

    private func beginAiSummaryRequest() -> Int {
        aiSummaryRequestVersion += 1
        loading = true
        aiRequestInFlight = true
        aiRequestTimedOut = false
        aiInlineErrorCode = nil
        aiInlineActionCode = nil
        aiTimeoutTask?.cancel()
        let requestVersion = aiSummaryRequestVersion
        aiTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard let self else { return }
            guard !Task.isCancelled else { return }
            guard self.isLatestAiSummaryRequest(requestVersion), self.aiRequestInFlight else { return }
            self.loading = false
            self.aiRequestInFlight = false
            self.aiRequestTimedOut = true
            self.aiInlineErrorCode = "timeout"
            self.aiInlineActionCode = "retry_now"
        }
        return aiSummaryRequestVersion
    }

    private func isLatestAiSummaryRequest(_ version: Int) -> Bool {
        version == aiSummaryRequestVersion
    }

    func loadAISummary(requestVersion: Int? = nil) async {
        let version = requestVersion ?? beginAiSummaryRequest()
        if requestVersion != nil && isLatestAiSummaryRequest(version) {
            loading = true
        }
        guard isLatestAiSummaryRequest(version) else { return }
        aiSummaryText = l("settings.ai_unavailable")
        aiTrendText = "-"
        aiTrendGraphText = "-"
        aiTrendPoints = []
        aiTrendFallbackPoints = []
        aiTrendGuardrailPoints = []
        aiTrendErrorPoints = []
        aiTrendTimeoutPoints = []
        aiTrendNetworkPoints = []
        aiTrendServerPoints = []
        aiRangeText = "-"
        aiTrendStartLabel = "-"
        aiTrendEndLabel = "-"
        aiLastUpdatedLabel = "-"
        aiBreakdownText = "-"
        aiTimeoutCount = 0
        aiNetworkCount = 0
        aiServerCount = 0
        aiErrorBreakdown = []
        statusText = l("settings.ai_unavailable")
        loading = false
        aiRequestInFlight = false
        aiRequestTimedOut = false
        aiInlineErrorCode = nil
        aiInlineActionCode = nil
        aiTimeoutTask?.cancel()
    }

    func scheduleAISummaryRefresh(force: Bool = false) {
        aiRefreshTask?.cancel()
        aiRefreshTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            if force || !self.aiTrendPoints.isEmpty {
                let version = self.beginAiSummaryRequest()
                await self.loadAISummary(requestVersion: version)
            }
        }
    }
}

private struct AITrendMiniChart: View {
    let points: [Int]
    let mode: SettingsViewModel.AIChartMode

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let values = points.isEmpty ? [0] : points
            let maxValue = max(values.max() ?? 1, 1)
            let minValue = values.min() ?? 0
            let span = max(maxValue - minValue, 1)
            let barCount = values.count
            let gap: CGFloat = 3
            let totalGap = gap * CGFloat(max(barCount - 1, 0))
            let barWidth = max((width - totalGap) / CGFloat(max(barCount, 1)), 2)

            if mode == .line {
                let stepX = values.count > 1 ? width / CGFloat(values.count - 1) : 0
                let pointsXY: [CGPoint] = values.enumerated().map { index, value in
                    let normalized = CGFloat(value - minValue) / CGFloat(span)
                    let y = height - max(4, normalized * (height - 2))
                    let x = CGFloat(index) * stepX
                    return CGPoint(x: x, y: y)
                }
                Path { path in
                    if let first = pointsXY.first {
                        path.move(to: first)
                        for point in pointsXY.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                ForEach(Array(pointsXY.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(index == pointsXY.count - 1 ? Color.white : Color.cyan.opacity(0.8))
                        .frame(width: index == pointsXY.count - 1 ? 7 : 5, height: index == pointsXY.count - 1 ? 7 : 5)
                        .position(point)
                }
            } else {
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        let normalized = CGFloat(value - minValue) / CGFloat(span)
                        let barHeight = max(4, normalized * (height - 2))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: normalized, isLatest: index == values.count - 1))
                            .frame(width: barWidth, height: barHeight)
                    }
                }
                .frame(width: width, height: height, alignment: .bottomLeading)
            }
        }
    }

    private func color(for normalized: CGFloat, isLatest: Bool) -> Color {
        let base: Color
        if normalized >= 0.75 {
            base = .red
        } else if normalized >= 0.4 {
            base = .orange
        } else {
            base = .blue
        }
        return isLatest ? base.opacity(0.9) : base.opacity(0.7)
    }
}

struct SettingsView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(session.l("common.city_updated"))
                    .font(.caption)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                Text(session.l("title.settings"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(HiAirV2Theme.primaryText)

                Text(session.l("settings.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.notifications"))
                        .font(.headline)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Toggle(session.l("settings.push"), isOn: $viewModel.pushAlertsEnabled)
                        .onChange(of: viewModel.pushAlertsEnabled) { enabled in
                            if enabled {
                                viewModel.registerPushDevice()
                            }
                        }
                    Toggle(session.l("settings.profile_alerting"), isOn: $viewModel.profileBasedAlerting)
                    Picker(session.l("settings.alert_threshold"), selection: $viewModel.riskThreshold) {
                        Text(session.l("settings.threshold_medium")).tag("medium")
                        Text(session.l("settings.threshold_high")).tag("high")
                        Text(session.l("settings.threshold_very_high")).tag("very_high")
                    }
                    .pickerStyle(.segmented)
                    Stepper("\(session.l("settings.quiet_start")): \(viewModel.quietHoursStart):00", value: $viewModel.quietHoursStart, in: 0...23)
                    Stepper("\(session.l("settings.quiet_end")): \(viewModel.quietHoursEnd):00", value: $viewModel.quietHoursEnd, in: 0...23)
                }
                .foregroundStyle(HiAirV2Theme.primaryText)
                .tint(HiAirV2Theme.accentStart)
                .v2Card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.profile_defaults"))
                        .font(.headline)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Picker(session.l("settings.persona"), selection: $viewModel.selectedPersona) {
                        Text(session.l("settings.persona_adult")).tag("adult")
                        Text(session.l("settings.persona_child")).tag("child")
                        Text(session.l("settings.persona_elderly")).tag("elderly")
                        Text(session.l("settings.persona_asthma")).tag("asthma")
                        Text(session.l("settings.persona_allergy")).tag("allergy")
                        Text(session.l("settings.persona_runner")).tag("runner")
                        Text(session.l("settings.persona_worker")).tag("worker")
                    }
                    .pickerStyle(.menu)
                    Picker(session.l("settings.language"), selection: $viewModel.preferredLanguage) {
                        Text(session.l("settings.language_ru")).tag("ru")
                        Text(session.l("settings.language_en")).tag("en")
                    }
                    .pickerStyle(.segmented)
                }
                .v2Card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.sync"))
                        .font(.headline)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    HStack(spacing: 8) {
                        Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.load")) {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.bordered)

                        Button(viewModel.loading ? session.l("settings.saving") : session.l("settings.save")) {
                            Task {
                                await viewModel.save()
                                session.persona = viewModel.selectedPersona
                                session.preferredLanguage = viewModel.preferredLanguage
                                if viewModel.pushAlertsEnabled {
                                    viewModel.registerPushDevice()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .disabled(viewModel.loading)
                    .tint(HiAirV2Theme.accentStart)
                    Text(viewModel.statusText)
                        .font(.footnote)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                    Button(session.l("settings.register_push_device")) {
                        viewModel.registerPushDevice()
                    }
                    .buttonStyle(.bordered)
                    Text(viewModel.pushRegistrationStatus)
                        .font(.footnote)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                }
                .v2Card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.subscription"))
                        .font(.headline)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Picker(session.l("settings.plan"), selection: $viewModel.selectedPlanId) {
                        ForEach(viewModel.plans, id: \.planId) { plan in
                            Text("\(plan.name) - $\(plan.priceUsd, specifier: "%.2f")").tag(plan.planId)
                        }
                    }
                    Text("\(session.l("settings.status")): \(viewModel.localizedSubscriptionStatus())")
                        .font(.footnote)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                    Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.load_plans")) {
                        Task { await viewModel.loadPlans() }
                    }
                    .buttonStyle(.bordered)
                    Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.load_subscription")) {
                        Task { await viewModel.loadSubscription() }
                    }
                    .buttonStyle(.bordered)
                    Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.activate_subscription")) {
                        Task { await viewModel.activateSubscription() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.loading || viewModel.selectedPlanId.isEmpty)
                    Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.cancel_subscription")) {
                        Task { await viewModel.cancelSubscription() }
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(viewModel.loading)
                .tint(HiAirV2Theme.accentStart)
                .v2Card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.security_privacy"))
                        .font(.headline)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    TextField(session.l("settings.user_id"), text: $viewModel.userId)
                        .textFieldStyle(.roundedBorder)
                    SecureField(session.l("settings.token"), text: $viewModel.accessToken)
                        .textFieldStyle(.roundedBorder)
                    Button(session.l("settings.log_out")) {
                        session.logout()
                        viewModel.userId = ""
                        viewModel.accessToken = ""
                        viewModel.subscriptionStatus = "inactive"
                        viewModel.statusText = session.l("settings.logged_out")
                    }
                    .foregroundStyle(.red)
                    Button(session.l("settings.export_privacy_data")) {
                        Task { await viewModel.exportPrivacyData() }
                    }
                    .buttonStyle(.bordered)
                    Button(session.l("settings.delete_account")) {
                        Task { await viewModel.deleteAccount(session: session) }
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                }
                .v2Card()

                Button(session.l("settings.sync_now")) {
                    Task {
                        await viewModel.save()
                        session.persona = viewModel.selectedPersona
                        session.preferredLanguage = viewModel.preferredLanguage
                        if viewModel.pushAlertsEnabled {
                            viewModel.registerPushDevice()
                        }
                    }
                }
                .buttonStyle(V2PrimaryButtonStyle())
                .disabled(viewModel.loading)
            }
            .padding(16)
        }
        .v2PageBackground()
        .onAppear {
            if viewModel.userId.isEmpty {
                viewModel.userId = session.userId
            }
            if viewModel.accessToken.isEmpty {
                viewModel.accessToken = session.accessToken
            }
            if viewModel.selectedPersona != session.persona {
                viewModel.selectedPersona = session.persona
            }
            if viewModel.preferredLanguage != session.preferredLanguage {
                viewModel.preferredLanguage = session.preferredLanguage
            }
            if viewModel.plans.isEmpty {
                Task { await viewModel.loadPlans() }
            }
            if viewModel.aiTrendPoints.isEmpty {
                viewModel.scheduleAISummaryRefresh(force: true)
            }
        }
        .onChange(of: viewModel.aiSummaryHours) { _ in
            viewModel.scheduleAISummaryRefresh(force: true)
        }
        .onChange(of: viewModel.aiChartMetric) { _ in
            if viewModel.aiTrendPoints.isEmpty {
                viewModel.scheduleAISummaryRefresh(force: true)
            }
        }
        .onChange(of: viewModel.aiChartMode) { _ in
            if viewModel.aiTrendPoints.isEmpty {
                viewModel.scheduleAISummaryRefresh(force: true)
            }
        }
        .onChange(of: viewModel.preferredLanguage) { newLanguage in
            session.preferredLanguage = newLanguage
        }
    }

    private func aiErrorBreakdownLine() -> String {
        let rendered = viewModel.aiErrorBreakdown
            .filter { $0.total > 0 }
            .prefix(3)
            .map { item in
                "\(session.l("settings.ai_error_type.\(item.errorType)")) \(item.total)"
            }
            .joined(separator: ", ")
        return "\(session.l("settings.ai_error_counts")): \(rendered.isEmpty ? "-" : rendered)"
    }
}
