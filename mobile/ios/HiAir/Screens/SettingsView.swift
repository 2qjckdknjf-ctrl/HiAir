import SwiftUI
import Foundation
import UIKit

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
    @Published var morningBriefingEnabled = false
    @Published var morningBriefingTime = "07:30"
    @Published var profileBasedAlerting = true
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
    @Published var privacyExportSummary = "-"
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
            let briefing = try await apiClient.fetchBriefingSchedule(userId: userId, accessToken: accessToken)
            morningBriefingEnabled = briefing.enabled
            morningBriefingTime = briefing.localTime
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
            _ = try await apiClient.updateBriefingSchedule(
                userId: userId,
                payload: BriefingScheduleUpdateRequest(localTime: morningBriefingTime, enabled: morningBriefingEnabled),
                accessToken: accessToken
            )
            statusText = l("settings.saved")
        } catch {
            statusText = l("settings.save_failed")
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
            let payload = try await apiClient.fetchPrivacyExport(userId: userId, accessToken: accessToken)
            let data = payload["data"] as? [String: Any]
            let sectionCount = data?.keys.count ?? 0
            privacyExportSummary = "\(l("settings.privacy_export_ready")): \(sectionCount)"
            statusText = l("settings.privacy_export_done")
        } catch {
            statusText = l("settings.privacy_export_failed")
        }
    }

    func deleteAccount() async -> Bool {
        guard !userId.isEmpty else {
            statusText = l("settings.user_id_required")
            return false
        }
        loading = true
        defer { loading = false }
        do {
            try await apiClient.deleteAccount(userId: userId, accessToken: accessToken)
            statusText = l("settings.account_deleted")
            userId = ""
            accessToken = ""
            privacyExportSummary = "-"
            return true
        } catch {
            statusText = l("settings.account_delete_failed")
            return false
        }
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
        do {
            let detailed = try await apiClient.fetchAISummaryDetailed(hours: aiSummaryHours)
            guard isLatestAiSummaryRequest(version) else { return }
            let summary = detailed.summary
            let fallbackPct = summary.fallbackRatePct ?? 0
            let guardrailPct = summary.guardrailBlockRatePct ?? 0
            let fallbackPctText = String(format: "%.1f", fallbackPct)
            let guardrailPctText = String(format: "%.1f", guardrailPct)
            aiSummaryText = "\(aiSummaryHours)h \(l("settings.ai_events")): \(summary.total), \(l("settings.ai_fallback")): \(summary.fallbackCount) (\(fallbackPctText)%), \(l("settings.ai_guardrail_blocks")): \(summary.guardrailBlockCount) (\(guardrailPctText)%)"
            if let lastPoint = detailed.trend.last {
                aiTrendText = "\(l("settings.ai_latest_hour")) \(lastPoint.hour): \(l("settings.metric.total")) \(lastPoint.total), \(l("settings.metric.fallback").lowercased()) \(lastPoint.fallbackCount), \(l("settings.ai_blocks_short")) \(lastPoint.guardrailBlockCount)"
            } else {
                aiTrendText = l("settings.ai_no_trend")
            }
            aiTrendPoints = detailed.trend.map { $0.total }
            aiTrendFallbackPoints = detailed.trend.map { $0.fallbackCount }
            aiTrendGuardrailPoints = detailed.trend.map { $0.guardrailBlockCount }
            aiTrendTimeoutPoints = detailed.trend.map { $0.timeoutCount ?? 0 }
            aiTrendNetworkPoints = detailed.trend.map { $0.networkCount ?? 0 }
            aiTrendServerPoints = detailed.trend.map { $0.serverCount ?? 0 }
            aiTrendErrorPoints = zip(aiTrendTimeoutPoints, zip(aiTrendNetworkPoints, aiTrendServerPoints)).map { timeout, pair in
                timeout + pair.0 + pair.1
            }
            aiTrendStartLabel = detailed.trend.first.map { hourLabel($0.hour) } ?? "-"
            aiTrendEndLabel = detailed.trend.last.map { hourLabel($0.hour) } ?? "-"
            aiLastUpdatedLabel = aiTrendEndLabel
            aiTrendGraphText = buildAsciiSparkline(points: currentAiTrendPoints)
            aiRangeText = rangeText(for: currentAiTrendPoints)
            let promptLine = detailed.breakdown.byPromptVersion.first.map {
                "\(l("settings.ai_top_prompt")): \($0.promptVersion) (\(l("settings.metric.total").lowercased()) \($0.total))"
            } ?? "\(l("settings.ai_top_prompt")): -"
            let modelLine = detailed.breakdown.byModelName.first.map {
                "\(l("settings.ai_top_model")): \($0.modelName) (\(l("settings.metric.total").lowercased()) \($0.total))"
            } ?? "\(l("settings.ai_top_model")): -"
            let errorCounts = detailed.breakdown.byErrorType
                .filter { $0.total > 0 }
            aiBreakdownText = "\(promptLine)\n\(modelLine)"
            aiTimeoutCount = summary.timeoutCount ?? 0
            aiNetworkCount = summary.networkCount ?? 0
            aiServerCount = summary.serverCount ?? 0
            aiErrorBreakdown = Array(errorCounts)
            statusText = l("settings.ai_loaded")
            loading = false
            aiRequestInFlight = false
            aiRequestTimedOut = false
            aiInlineErrorCode = nil
            aiInlineActionCode = nil
            aiTimeoutTask?.cancel()
        } catch {
            guard isLatestAiSummaryRequest(version) else { return }
            if aiRequestTimedOut {
                return
            }
            let errorCode: String
            let actionCode: String
            if let apiError = error as? APIError {
                switch apiError {
                case .server(let statusCode):
                    if statusCode >= 500 {
                        errorCode = "server"
                        actionCode = "retry_later"
                    } else {
                        errorCode = "failed"
                        actionCode = "retry_now"
                    }
                default:
                    errorCode = "failed"
                    actionCode = "retry_now"
                }
            } else if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    errorCode = "timeout"
                    actionCode = "retry_now"
                case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                    errorCode = "network"
                    actionCode = "retry_now"
                default:
                    errorCode = "failed"
                    actionCode = "retry_now"
                }
            } else {
                errorCode = "failed"
                actionCode = "retry_now"
            }
            aiSummaryText = l("settings.ai_failed")
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
            statusText = l("settings.ai_request_failed")
            loading = false
            aiRequestInFlight = false
            aiRequestTimedOut = (errorCode == "timeout")
            aiInlineErrorCode = errorCode
            aiInlineActionCode = actionCode
            aiTimeoutTask?.cancel()
        }
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

private struct TokenSwatchRow: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
            Text(title)
                .font(.footnote)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            Spacer()
            Text(colorHex)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(HiAirV2Theme.tertiaryText)
        }
    }

    private var colorHex: String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Developer · Design tokens")
                        .font(.headline)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    TokenSwatchRow(title: "Risk low", color: AuroraTokens.ColorPalette.riskLow)
                    TokenSwatchRow(title: "Risk moderate", color: AuroraTokens.ColorPalette.riskModerate)
                    TokenSwatchRow(title: "Risk high", color: AuroraTokens.ColorPalette.riskHigh)
                    TokenSwatchRow(title: "Risk very high", color: AuroraTokens.ColorPalette.riskVeryHigh)
                    TokenSwatchRow(title: "CTA start", color: AuroraTokens.ColorPalette.ctaStart)
                    TokenSwatchRow(title: "CTA end", color: AuroraTokens.ColorPalette.ctaEnd)
                }
                .v2Card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.notifications"))
                        .font(.headline)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Toggle(session.l("settings.push"), isOn: $viewModel.pushAlertsEnabled)
                    Toggle(session.l("settings.morning_briefing"), isOn: $viewModel.morningBriefingEnabled)
                    TextField(session.l("settings.morning_briefing_time"), text: $viewModel.morningBriefingTime)
                        .textFieldStyle(.roundedBorder)
                    if viewModel.userId.isEmpty {
                        Text(session.l("settings.briefing_setup_hint"))
                            .font(.caption)
                            .foregroundStyle(HiAirV2Theme.tertiaryText)
                    }
                    Text(session.l("settings.morning_briefing_hint"))
                        .font(.caption)
                        .foregroundStyle(HiAirV2Theme.tertiaryText)
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
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .disabled(viewModel.loading)
                    .tint(HiAirV2Theme.accentStart)
                    Text(viewModel.statusText)
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
                    Text(session.l("settings.ai_observability"))
                        .font(.headline)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Picker(session.l("settings.window"), selection: $viewModel.aiSummaryHours) {
                        Text(session.l("settings.window_24h")).tag(24)
                        Text(session.l("settings.window_72h")).tag(72)
                    }
                    .pickerStyle(.segmented)
                    Button(viewModel.loading ? session.l("settings.loading_ai_metrics") : session.l("settings.load_ai_summary")) {
                        Task { await viewModel.loadAISummary() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.loading)
                    .tint(HiAirV2Theme.accentStart)
                    Text(viewModel.aiSummaryText)
                        .font(.footnote)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                    Text(viewModel.aiTrendText)
                        .font(.footnote)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                    DisclosureGroup(session.l("settings.advanced_controls")) {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker(session.l("settings.metric"), selection: $viewModel.aiChartMetric) {
                                ForEach(SettingsViewModel.AIChartMetric.allCases) { metric in
                                    Text(session.l(metric.title)).tag(metric)
                                }
                            }
                            .pickerStyle(.segmented)
                            Picker(session.l("settings.mode"), selection: $viewModel.aiChartMode) {
                                ForEach(SettingsViewModel.AIChartMode.allCases) { mode in
                                    Text(session.l(mode.title)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            Text(viewModel.aiTrendGraphText)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(HiAirV2Theme.accentStart)
                            Text("\(session.l("settings.range")): \(viewModel.aiRangeText)")
                                .font(.footnote)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Text("\(session.l("settings.axis")): \(viewModel.aiTrendStartLabel) -> \(viewModel.aiTrendEndLabel)")
                                .font(.footnote)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Text("\(session.l("settings.request_status")): \(viewModel.aiRequestInFlight ? session.l("settings.request_loading") : (viewModel.aiRequestTimedOut ? session.l("settings.request_timeout") : session.l("settings.request_idle")))")
                                .font(.footnote)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Text("\(session.l("settings.last_updated")): \(viewModel.aiLastUpdatedLabel)")
                                .font(.footnote)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            if let errorCode = viewModel.aiInlineErrorCode {
                                let errorTextKey: String = {
                                    switch errorCode {
                                    case "timeout": return "settings.ai_timeout_inline"
                                    case "network": return "settings.ai_network_inline"
                                    case "server": return "settings.ai_server_inline"
                                    default: return "settings.ai_request_failed_inline"
                                    }
                                }()
                                let actionCode = viewModel.aiInlineActionCode ?? "retry_now"
                                Text(session.l(errorTextKey))
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                Button(session.l(actionCode == "retry_later" ? "settings.ai_retry_later" : "settings.ai_retry_now")) {
                                    viewModel.scheduleAISummaryRefresh(force: true)
                                }
                                .buttonStyle(.bordered)
                                .disabled(actionCode == "retry_later")
                            }
                            AITrendMiniChart(points: viewModel.currentAiTrendPoints, mode: viewModel.aiChartMode)
                                .frame(height: 74)
                            Text(viewModel.aiBreakdownText)
                                .font(.footnote)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Text("\(session.l("settings.ai_error_counts")): \(session.l("settings.ai_error_type.timeout")) \(viewModel.aiTimeoutCount), \(session.l("settings.ai_error_type.network")) \(viewModel.aiNetworkCount), \(session.l("settings.ai_error_type.server")) \(viewModel.aiServerCount)")
                                .font(.footnote)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Text(aiErrorBreakdownLine())
                                .font(.footnote)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                        }
                    }
                }
                .v2Card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.security_privacy"))
                        .font(.headline)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    TextField(session.l("settings.user_id"), text: $viewModel.userId)
                        .textFieldStyle(.roundedBorder)
                    SecureField(session.l("settings.token"), text: $viewModel.accessToken)
                        .textFieldStyle(.roundedBorder)
                    Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.privacy_export")) {
                        Task { await viewModel.exportPrivacyData() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.loading)
                    Text(viewModel.privacyExportSummary)
                        .font(.footnote)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                    Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.delete_account")) {
                        Task {
                            let deleted = await viewModel.deleteAccount()
                            if deleted {
                                session.logout()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.loading)
                    .foregroundStyle(.red)
                    Button(session.l("settings.log_out")) {
                        session.logout()
                        viewModel.userId = ""
                        viewModel.accessToken = ""
                        viewModel.subscriptionStatus = "inactive"
                        viewModel.statusText = session.l("settings.logged_out")
                        viewModel.privacyExportSummary = "-"
                    }
                    .foregroundStyle(.red)
                }
                .v2Card()

                Button(session.l("settings.sync_now")) {
                    Task {
                        await viewModel.save()
                        session.persona = viewModel.selectedPersona
                        session.preferredLanguage = viewModel.preferredLanguage
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
