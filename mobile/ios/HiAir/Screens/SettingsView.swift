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
    @Published var morningBriefingEnabled = false
    @Published var morningBriefingTime = "07:30"
    @Published var profileBasedAlerting = true
    @Published var selectedPersona = "adult"
    @Published var preferredLanguage = "ru"
    @Published var dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @Published var profileId = ""
    @Published var plans: [SubscriptionPlan] = []
    @Published var selectedPlanId = "basic_monthly"
    @Published var subscriptionStatus = "inactive"
    var onEntitlementChanged: ((UserEntitlementResponse?) -> Void)?
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
    @Published var wearableStatus = "-"
    @Published var savedPlaces: [SavedPlace] = []
    @Published var placesStatusText = ""
    @Published var profileHomeLat: Double?
    @Published var profileHomeLon: Double?
    @Published var workWorkload = "moderate"
    @Published var workSiteRiskText = ""
    @Published var workSiteRiskProxyOnly = false
    @Published var workSiteRiskLoading = false
    @Published var familyMembers: [FamilyMemberLink] = []
    @Published var familyRiskByLinkId: [String: FamilyMemberRiskLine] = [:]
    @Published var familyStatusText = ""
    @Published var availableProfiles: [UserProfile] = []
    @Published var statusText = "-"
    @Published var loading = false

    private let apiClient: APIClient

    init(apiClient: APIClient = .live()) {
        self.apiClient = apiClient
    }
    private var aiRefreshTask: Task<Void, Never>?
    private var aiSummaryRequestVersion: Int = 0
    private var aiTimeoutTask: Task<Void, Never>?

    private func l(_ key: String) -> String {
        HiAirL10n.t(key, lang: preferredLanguage)
    }

    func ageYearsLabel() -> String {
        let years = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
        return "\(max(years, 0))"
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

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func load() async {
        guard !userId.isEmpty else {
            statusText = l("settings.user_id_required")
            return
        }
        loading = true
        defer { loading = false }
        do {
            let profiles = try await apiClient.listProfiles(userId: userId, accessToken: accessToken)
            availableProfiles = profiles
            if let profile = profiles.first {
                profileId = profile.id
                selectedPersona = profile.personaType
                profileHomeLat = profile.homeLat
                profileHomeLon = profile.homeLon
                if let raw = profile.dateOfBirth, let parsed = Self.birthDateFormatter.date(from: raw) {
                    dateOfBirth = parsed
                }
            }
            await loadSavedPlaces()
            await loadFamilyMembers()
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
            ProductAnalytics.track("morning_briefing_viewed", properties: ["enabled": briefing.enabled ? "true" : "false"])
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
            if !profileId.isEmpty {
                _ = try await apiClient.updateProfile(
                    userId: userId,
                    profileId: profileId,
                    payload: ProfileUpdatePayload(
                        personaType: selectedPersona,
                        sensitivityLevel: nil,
                        homeLat: nil,
                        homeLon: nil,
                        dateOfBirth: Self.birthDateFormatter.string(from: dateOfBirth)
                    ),
                    accessToken: accessToken
                )
            }
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
            ProductAnalytics.track("privacy_export")
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
            ProductAnalytics.track("privacy_delete")
            userId = ""
            accessToken = ""
            privacyExportSummary = "-"
            return true
        } catch {
            statusText = l("settings.account_delete_failed")
            return false
        }
    }

    func loadSavedPlaces() async {
        guard !userId.isEmpty else { return }
        do {
            let response = try await apiClient.listPlaces(userId: userId, accessToken: accessToken)
            savedPlaces = response.places
            placesStatusText = ""
        } catch {
            placesStatusText = l("settings.places.load_failed")
        }
    }

    func loadFamilyMembers() async {
        guard !userId.isEmpty else { return }
        do {
            let response = try await apiClient.listFamilyMembers(userId: userId, accessToken: accessToken)
            familyMembers = response.members
            familyStatusText = ""
            await loadFamilyRiskOverview()
        } catch {
            familyStatusText = l("settings.family.load_failed")
        }
    }

    func loadFamilyRiskOverview() async {
        guard !userId.isEmpty else { return }
        do {
            let overview = try await apiClient.fetchFamilyRiskOverview(userId: userId, accessToken: accessToken)
            familyRiskByLinkId = Dictionary(uniqueKeysWithValues: overview.members.map { ($0.memberLinkId, $0) })
        } catch {
            familyRiskByLinkId = [:]
        }
    }

    func familyRiskLabel(for memberId: String, language: String) -> String {
        guard let line = familyRiskByLinkId[memberId] else { return "" }
        if !line.available {
            return HiAirL10n.t("settings.family.risk_unavailable", lang: language)
        }
        let levelKey: String? = switch line.riskLevel.lowercased() {
        case "low": "hazards.level.low"
        case "moderate", "medium": "hazards.level.moderate"
        case "high": "hazards.level.high"
        case "very_high", "very high": "hazards.level.very_high"
        default: nil
        }
        let level = levelKey.map { HiAirL10n.t($0, lang: language) } ?? line.riskLevel
        return HiAirL10n.t("settings.family.risk_line", lang: language)
            .replacingOccurrences(of: "%@", with: level)
            .replacingOccurrences(of: "%d", with: String(line.riskScore))
    }

    func addFamilyMember(profileId: String, relation: String, label: String?) async {
        guard !userId.isEmpty, !profileId.isEmpty else { return }
        familyStatusText = ""
        do {
            let member = try await apiClient.createFamilyMember(
                payload: FamilyMemberCreateRequest(
                    memberProfileId: profileId,
                    relation: relation,
                    label: label?.isEmpty == true ? nil : label
                ),
                userId: userId,
                accessToken: accessToken
            )
            familyMembers.append(member)
            familyStatusText = l("settings.family.added")
        } catch {
            familyStatusText = l("settings.family.add_failed")
        }
    }

    func deleteFamilyMember(_ linkId: String) async {
        guard !userId.isEmpty else { return }
        do {
            try await apiClient.deleteFamilyMember(memberLinkId: linkId, userId: userId, accessToken: accessToken)
            familyMembers.removeAll { $0.id == linkId }
            familyStatusText = l("settings.family.deleted")
        } catch {
            familyStatusText = l("settings.family.delete_failed")
        }
    }

    func loadWorkSiteRisk() async {
        guard !userId.isEmpty,
              let lat = profileHomeLat,
              let lon = profileHomeLon else {
            workSiteRiskText = l("settings.work.no_location")
            return
        }
        workSiteRiskLoading = true
        defer { workSiteRiskLoading = false }
        do {
            let response = try await apiClient.fetchSiteRisk(
                lat: lat,
                lon: lon,
                workload: workWorkload,
                acclimatized: true,
                userId: userId,
                accessToken: accessToken
            )
            let assessment = response.assessment
            workSiteRiskProxyOnly = assessment.reasonCodes.contains("heat_index_proxy_only")
            let workRest = String(
                format: l("settings.work.work_rest"),
                assessment.workRest.workMinutes,
                assessment.workRest.restMinutes
            )
            workSiteRiskText = String(
                format: l("settings.work.summary"),
                assessment.riskLevel,
                workRest
            )
        } catch {
            workSiteRiskText = l("settings.work.load_failed")
            workSiteRiskProxyOnly = false
        }
    }

    func addHomePlace(name: String, lat: Double, lon: Double, timezone: String?) async {
        guard !userId.isEmpty else { return }
        placesStatusText = ""
        do {
            let place = try await apiClient.createPlace(
                payload: SavedPlaceCreateRequest(
                    name: name,
                    placeType: "home",
                    lat: lat,
                    lon: lon,
                    timezone: timezone
                ),
                userId: userId,
                accessToken: accessToken
            )
            savedPlaces.append(place)
            placesStatusText = l("settings.places.added")
        } catch {
            placesStatusText = l("settings.places.add_failed")
        }
    }

    func deleteSavedPlace(_ placeId: String) async {
        guard !userId.isEmpty else { return }
        placesStatusText = ""
        do {
            try await apiClient.deletePlace(placeId: placeId, userId: userId, accessToken: accessToken)
            savedPlaces.removeAll { $0.id == placeId }
            placesStatusText = l("settings.places.deleted")
        } catch {
            placesStatusText = l("settings.places.delete_failed")
        }
    }

    func refreshWearableStatus() async {
        let service = HealthKitService.shared
        let expectedUserId = userId
        let expectedToken = accessToken
        // Prefer live connectionState; demote stale Connected without durable consent first.
        if service.connectionState == .notConnected {
            _ = service.refreshAuthorizationState()
        } else if !expectedUserId.isEmpty {
            _ = service.demoteConnectedWithoutDurableConsent(for: expectedUserId)
        }
        let hkState = service.connectionState
        guard !expectedUserId.isEmpty else {
            wearableStatus = wearableStatusLabel(
                for: hkState,
                consentActive: false,
                hasDurableConsent: false,
                hasSystemAuthorization: false
            )
            return
        }

        // UITest-only inactive seed: exercise production WearableStatusPresentation with
        // durable=true + consentActive=false without network/upload/delete. Gated by -UITesting.
        if UITestBootstrap.seedWearableDurableInactive {
            let durable = service.hasDurableConsent(for: expectedUserId)
            let systemAuth = service.hasSystemAuthorization(for: expectedUserId)
            // Keep durable marker; demote stale `.connected` presentation to OS-authorized.
            if service.connectionState == .connected || service.connectionState == .dataUnavailable
                || service.connectionState == .syncFailed || service.connectionState == .partial
            {
                service.reportConnectionState(systemAuth ? .systemAuthorized : .notConnected)
            }
            wearableStatus = wearableStatusLabel(
                for: service.connectionState,
                consentActive: false,
                hasDurableConsent: durable,
                hasSystemAuthorization: systemAuth
            )
            return
        }

        do {
            let today = try await apiClient.fetchWearableToday(
                userId: expectedUserId,
                accessToken: expectedToken
            )
            // Drop stale async refresh after logout / account switch.
            guard userId == expectedUserId else { return }
            let consentActive = today.consent?.isActive == true
            let hkBefore = service.connectionState
            // Never rehydrate Connected while local revoke is pending/failed (fail-closed).
            let revokeInFlight: Bool
            switch hkBefore {
            case .revoking, .remoteRevokePending, .revokeFailed:
                revokeInFlight = true
            default:
                revokeInFlight = false
            }
            if !revokeInFlight {
                service.reconcileServerConsent(userId: expectedUserId, isActive: consentActive)
            } else {
                _ = service.demoteConnectedWithoutDurableConsent(for: expectedUserId)
            }
            let hkAfter = service.connectionState
            let durable = service.hasDurableConsent(for: expectedUserId)
            let systemAuth = service.hasSystemAuthorization(for: expectedUserId)
            // Account "подключено" requires server-active + durable consent — never OS auth alone.
            let accountConsentActive = !revokeInFlight && consentActive && durable
            wearableStatus = wearableStatusLabel(
                for: hkAfter,
                consentActive: accountConsentActive,
                hasDurableConsent: durable,
                hasSystemAuthorization: systemAuth
            )
        } catch {
            guard userId == expectedUserId else { return }
            let durable = service.hasDurableConsent(for: expectedUserId)
            _ = service.demoteConnectedWithoutDurableConsent(for: expectedUserId)
            // Transport/server failure must not flip durable consent into "inactive".
            // Keep local durable as active for presentation; demote only stale connected without durable.
            wearableStatus = wearableStatusLabel(
                for: service.connectionState,
                consentActive: durable,
                hasDurableConsent: durable,
                hasSystemAuthorization: service.hasSystemAuthorization(for: expectedUserId)
            )
        }
    }

    func wearableStatusLabel(
        for hkState: WearableConnectionState,
        consentActive: Bool,
        hasDurableConsent: Bool,
        hasSystemAuthorization: Bool
    ) -> String {
        WearableStatusPresentation.statusLabel(
            connectionState: hkState,
            consentActive: consentActive,
            hasDurableConsent: hasDurableConsent,
            hasSystemAuthorization: hasSystemAuthorization,
            localize: { l($0) }
        )
    }

    func disconnectWearables() async {
        guard !userId.isEmpty else { return }
        // Local consent + sync cancel happen inside the service before any remote await.
        // Do not call the API first — that would leave durable consent true during the wait.
        await HealthKitService.shared.revokeConsent(userId: userId, accessToken: accessToken)
        await refreshWearableStatus()
    }

    func deleteWearableData() async {
        guard !userId.isEmpty else { return }
        // HealthKitService owns remote delete + local fail-closed clear.
        await HealthKitService.shared.deleteHealthData(userId: userId, accessToken: accessToken)
        await refreshWearableStatus()
        switch HealthKitService.shared.connectionState {
        case .revokeFailed, .remoteRevokePending, .revoking:
            // Do not claim full remote deletion on partial failure.
            statusText = l("wearable.consent.revoke_failed")
        default:
            statusText = l("settings.wearables.delete_done")
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
            onEntitlementChanged?(subscription.entitlement)
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
            onEntitlementChanged?(subscription.entitlement)
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
            onEntitlementChanged?(subscription.entitlement)
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
                .stroke(AuroraTokens.ColorPalette.info, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                ForEach(Array(pointsXY.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(index == pointsXY.count - 1 ? AuroraTokens.ColorPalette.textPrimary : AuroraTokens.ColorPalette.info.opacity(0.8))
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
            base = AuroraTokens.ColorPalette.riskHigh
        } else if normalized >= 0.4 {
            base = AuroraTokens.ColorPalette.riskModerate
        } else {
            base = AuroraTokens.ColorPalette.riskLow
        }
        return isLatest ? base.opacity(0.9) : base.opacity(0.7)
    }
}

struct SettingsView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingGuide = false
    @State private var showingAIGuide = false
    @State private var showWearableConsent = false

    var body: some View {
        HiAirAdaptiveLayout { width, mode in
            ScrollView {
                VStack(alignment: .leading, spacing: HiAirResponsiveSpacing.sectionSpacing(for: mode)) {
                Text(session.l("title.settings"))
                    .font(AuroraTokens.Typography.displayLG)
                    .foregroundStyle(HiAirV2Theme.primaryText)

                Text(session.l("settings.subtitle"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.notifications"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Toggle(session.l("settings.push"), isOn: $viewModel.pushAlertsEnabled)
                    if !viewModel.pushAlertsEnabled {
                        Text(session.l("settings.notifications_off_hint"))
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.tertiaryText)
                    }
                    Toggle(session.l("settings.morning_briefing"), isOn: $viewModel.morningBriefingEnabled)
                    TextField(session.l("settings.morning_briefing_time"), text: $viewModel.morningBriefingTime)
                        .textFieldStyle(.roundedBorder)
                    if viewModel.userId.isEmpty {
                        Text(session.l("settings.briefing_setup_hint"))
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.tertiaryText)
                    }
                    Text(session.l("settings.morning_briefing_hint"))
                        .font(AuroraTokens.Typography.caption)
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
                        .font(AuroraTokens.Typography.titleMD)
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
                        Text(session.l("settings.language_es")).tag("es")
                        Text(session.l("settings.language_it")).tag("it")
                        Text(session.l("settings.language_fr")).tag("fr")
                    }
                    .pickerStyle(.menu)
                    DatePicker(
                        session.l("settings.date_of_birth"),
                        selection: $viewModel.dateOfBirth,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: Self.localeIdentifier(for: session.preferredLanguage)))
                    Text("\(session.l("settings.age_years")): \(viewModel.ageYearsLabel())")
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                }
                .v2Card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.sync"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    HStack(spacing: 8) {
                        Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.load")) {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())

                        Button(viewModel.loading ? session.l("settings.saving") : session.l("settings.save")) {
                            Task {
                                await viewModel.save()
                                session.persona = viewModel.selectedPersona
                                session.preferredLanguage = viewModel.preferredLanguage
                                session.dateOfBirth = viewModel.dateOfBirth
                            }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                    }
                    .disabled(viewModel.loading)
                    .tint(HiAirV2Theme.accentStart)
                    Text(viewModel.statusText)
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                }
                .v2Card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.subscription"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Text(
                        session.isPremium
                            ? session.l("settings.premium_active")
                            : session.l("settings.premium_inactive")
                    )
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
                    Button(session.l("settings.upgrade_premium")) {
                        session.showPaywall = true
                    }
                    .buttonStyle(HiAirGradientButtonStyle())
                    .accessibilityIdentifier(HiAirAccessibilityID.Settings.openPaywall)
                    #if DEBUG
                    DisclosureGroup(session.l("settings.subscription_dev")) {
                        Picker(session.l("settings.plan"), selection: $viewModel.selectedPlanId) {
                            ForEach(viewModel.plans, id: \.planId) { plan in
                                Text(planLabel(plan)).tag(plan.planId)
                            }
                        }
                        Text("\(session.l("settings.status")): \(viewModel.localizedSubscriptionStatus())")
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                        Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.load_plans")) {
                            Task { await viewModel.loadPlans() }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                        Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.load_subscription")) {
                            Task { await viewModel.loadSubscription() }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                        Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.activate_subscription")) {
                            Task { await viewModel.activateSubscription() }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                        .disabled(viewModel.loading || viewModel.selectedPlanId.isEmpty)
                        Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.cancel_subscription")) {
                            Task { await viewModel.cancelSubscription() }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                    }
                    .font(AuroraTokens.Typography.caption)
                    #endif
                    if !viewModel.statusText.isEmpty && viewModel.statusText != "-" {
                        Text(viewModel.statusText)
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.tertiaryText)
                    }
                }
                .tint(HiAirV2Theme.accentStart)
                .v2Card()

                #if DEBUG
                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.ai_observability"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Picker(session.l("settings.window"), selection: $viewModel.aiSummaryHours) {
                        Text(session.l("settings.window_24h")).tag(24)
                        Text(session.l("settings.window_72h")).tag(72)
                    }
                    .pickerStyle(.segmented)
                    Button(viewModel.loading ? session.l("settings.loading_ai_metrics") : session.l("settings.load_ai_summary")) {
                        Task { await viewModel.loadAISummary() }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    .disabled(viewModel.loading)
                    .tint(HiAirV2Theme.accentStart)
                    Text(viewModel.aiSummaryText)
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                    Text(viewModel.aiTrendText)
                        .font(AuroraTokens.Typography.caption)
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
                                .font(AuroraTokens.Typography.caption)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Text("\(session.l("settings.axis")): \(viewModel.aiTrendStartLabel) -> \(viewModel.aiTrendEndLabel)")
                                .font(AuroraTokens.Typography.caption)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Text("\(session.l("settings.request_status")): \(viewModel.aiRequestInFlight ? session.l("settings.request_loading") : (viewModel.aiRequestTimedOut ? session.l("settings.request_timeout") : session.l("settings.request_idle")))")
                                .font(AuroraTokens.Typography.caption)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Text("\(session.l("settings.last_updated")): \(viewModel.aiLastUpdatedLabel)")
                                .font(AuroraTokens.Typography.caption)
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
                                    .font(AuroraTokens.Typography.caption)
                                    .foregroundStyle(AuroraTokens.ColorPalette.errorSoft)
                                Button(session.l(actionCode == "retry_later" ? "settings.ai_retry_later" : "settings.ai_retry_now")) {
                                    viewModel.scheduleAISummaryRefresh(force: true)
                                }
                                .buttonStyle(HiAirSecondaryButtonStyle())
                                .disabled(actionCode == "retry_later")
                            }
                            AITrendMiniChart(points: viewModel.currentAiTrendPoints, mode: viewModel.aiChartMode)
                                .frame(height: 74)
                            Text(viewModel.aiBreakdownText)
                                .font(AuroraTokens.Typography.caption)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Text("\(session.l("settings.ai_error_counts")): \(session.l("settings.ai_error_type.timeout")) \(viewModel.aiTimeoutCount), \(session.l("settings.ai_error_type.network")) \(viewModel.aiNetworkCount), \(session.l("settings.ai_error_type.server")) \(viewModel.aiServerCount)")
                                .font(AuroraTokens.Typography.caption)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Text(aiErrorBreakdownLine())
                                .font(AuroraTokens.Typography.caption)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                        }
                    }
                }
                .v2Card()
                #endif

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.help_title"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Button(session.l("settings.help_open")) {
                        showingGuide = true
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    Button(session.l("settings.ai_guide_open")) {
                        showingAIGuide = true
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    Button(session.l("settings.onboarding_reopen")) {
                        session.showOnboardingFromSettings = true
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    Button(session.l("dashboard.get_started.title")) {
                        session.resetChecklist()
                        session.selectedTab = 0
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                }
                .tint(HiAirV2Theme.accentStart)
                .v2Card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.places.title"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    if viewModel.savedPlaces.isEmpty {
                        Text(session.l("settings.places.empty"))
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                    } else {
                        ForEach(viewModel.savedPlaces) { place in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .font(AuroraTokens.Typography.bodyMD)
                                        .foregroundStyle(HiAirV2Theme.primaryText)
                                    Text(
                                        String(
                                            format: session.l("settings.places.coords"),
                                            locale: Locale(identifier: session.preferredLanguage),
                                            place.lat,
                                            place.lon
                                        )
                                    )
                                    .font(AuroraTokens.Typography.caption)
                                    .foregroundStyle(HiAirV2Theme.tertiaryText)
                                }
                                Spacer()
                                Button(session.l("settings.places.delete")) {
                                    Task { await viewModel.deleteSavedPlace(place.id) }
                                }
                                .buttonStyle(HiAirSecondaryButtonStyle())
                            }
                        }
                    }
                    if session.hasValidLocation || GeoCoordinates.isValid(
                        lat: viewModel.profileHomeLat ?? 0,
                        lon: viewModel.profileHomeLon ?? 0
                    ) {
                        Button(session.l("settings.places.add_home")) {
                            let lat = session.hasValidLocation ? session.latitude : (viewModel.profileHomeLat ?? 0)
                            let lon = session.hasValidLocation ? session.longitude : (viewModel.profileHomeLon ?? 0)
                            let name = session.displayPlaceName?.trimmingCharacters(in: .whitespacesAndNewlines)
                            let resolvedName = (name?.isEmpty == false) ? name! : session.l("settings.places.home_default_name")
                            Task {
                                await viewModel.addHomePlace(
                                    name: resolvedName,
                                    lat: lat,
                                    lon: lon,
                                    timezone: TimeZone.current.identifier
                                )
                            }
                        }
                        .buttonStyle(HiAirGradientButtonStyle())
                    }
                    if !viewModel.placesStatusText.isEmpty {
                        Text(viewModel.placesStatusText)
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                    }
                }
                .v2Card()
                .onAppear {
                    Task { await viewModel.loadSavedPlaces() }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.work.title"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Text(session.l("settings.work.subtitle"))
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                    Picker(session.l("settings.work.workload"), selection: $viewModel.workWorkload) {
                        Text(session.l("settings.work.workload.light")).tag("light")
                        Text(session.l("settings.work.workload.moderate")).tag("moderate")
                        Text(session.l("settings.work.workload.heavy")).tag("heavy")
                        Text(session.l("settings.work.workload.very_heavy")).tag("very_heavy")
                    }
                    .pickerStyle(.menu)
                    Button(viewModel.workSiteRiskLoading ? session.l("common.loading") : session.l("settings.work.refresh")) {
                        Task { await viewModel.loadWorkSiteRisk() }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    if !viewModel.workSiteRiskText.isEmpty {
                        Text(viewModel.workSiteRiskText)
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                    }
                    if viewModel.workSiteRiskProxyOnly {
                        Text(session.l("settings.work.proxy_disclaimer"))
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.tertiaryText)
                    }
                }
                .v2Card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.family.title"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Text(session.l("settings.family.subtitle"))
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                    if viewModel.familyMembers.isEmpty {
                        Text(session.l("settings.family.empty"))
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                    } else {
                        ForEach(viewModel.familyMembers) { member in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.label ?? member.memberProfileId)
                                        .font(AuroraTokens.Typography.bodyMD)
                                    Text(session.l("settings.family.relation.\(member.relation)"))
                                        .font(AuroraTokens.Typography.caption)
                                        .foregroundStyle(HiAirV2Theme.tertiaryText)
                                    let riskLabel = viewModel.familyRiskLabel(for: member.id, language: session.preferredLanguage)
                                    if !riskLabel.isEmpty {
                                        Text(riskLabel)
                                            .font(AuroraTokens.Typography.caption)
                                            .foregroundStyle(HiAirV2Theme.secondaryText)
                                    }
                                }
                                Spacer()
                                Button(session.l("settings.family.delete")) {
                                    Task { await viewModel.deleteFamilyMember(member.id) }
                                }
                                .buttonStyle(HiAirSecondaryButtonStyle())
                            }
                        }
                    }
                    ForEach(
                        viewModel.availableProfiles.filter { profile in
                            profile.id != viewModel.profileId
                                && !viewModel.familyMembers.contains(where: { $0.memberProfileId == profile.id })
                        }
                    ) { profile in
                        HStack {
                            Text(profile.personaType)
                                .font(AuroraTokens.Typography.bodyMD)
                            Spacer()
                            Button(session.l("settings.family.add")) {
                                Task {
                                    await viewModel.addFamilyMember(
                                        profileId: profile.id,
                                        relation: "child",
                                        label: profile.personaType
                                    )
                                }
                            }
                            .buttonStyle(HiAirSecondaryButtonStyle())
                        }
                    }
                    if !viewModel.familyStatusText.isEmpty {
                        Text(viewModel.familyStatusText)
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                    }
                }
                .v2Card()
                .onAppear {
                    Task { await viewModel.loadFamilyMembers() }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.wearables.title"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                        .accessibilityIdentifier("settings.wearables.title")
                    Text(viewModel.wearableStatus)
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                        .accessibilityIdentifier("settings.wearables.status")
                    if let errorText = session.lHealthKitError(HealthKitService.shared.lastAuthorizationError) {
                        Text(errorText)
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(AuroraTokens.ColorPalette.errorSoft)
                    }
                    Button(session.l("settings.wearables.connect")) {
                        showWearableConsent = true
                    }
                    .buttonStyle(HiAirGradientButtonStyle())
                    .accessibilityIdentifier("settings.wearables.connect")
                    Button(session.l("settings.wearables.disconnect")) {
                        Task { await viewModel.disconnectWearables() }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    .accessibilityIdentifier("settings.wearables.disconnect")
                    Button(session.l("settings.wearables.delete")) {
                        Task { await viewModel.deleteWearableData() }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    .accessibilityIdentifier("settings.wearables.delete")
                }
                .v2Card()
                .onAppear {
                    Task { await viewModel.refreshWearableStatus() }
                }
                .sheet(isPresented: $showWearableConsent) {
                    WearableConsentView(fromOnboarding: false) {
                        Task { await viewModel.refreshWearableStatus() }
                    }
                    .environmentObject(session)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("settings.security_privacy"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    if !session.email.isEmpty {
                        Text(session.email)
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                    }
                    Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.privacy_export")) {
                        Task { await viewModel.exportPrivacyData() }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    .disabled(viewModel.loading)
                    if !viewModel.privacyExportSummary.isEmpty && viewModel.privacyExportSummary != "-" {
                        Text(viewModel.privacyExportSummary)
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                    }
                    Button(viewModel.loading ? session.l("settings.loading") : session.l("settings.delete_account")) {
                        Task {
                            let deleted = await viewModel.deleteAccount()
                            if deleted {
                                session.logout()
                            }
                        }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    .disabled(viewModel.loading)
                    .foregroundStyle(AuroraTokens.ColorPalette.errorSoft)
                    Button(session.l("settings.log_out")) {
                        session.logout()
                        viewModel.userId = ""
                        viewModel.accessToken = ""
                        viewModel.subscriptionStatus = "inactive"
                        viewModel.statusText = session.l("settings.logged_out")
                        viewModel.privacyExportSummary = ""
                    }
                    .foregroundStyle(AuroraTokens.ColorPalette.errorSoft)
                    .accessibilityIdentifier(HiAirAccessibilityID.Settings.logout)
                }
                .v2Card()

                Button(session.l("settings.sync_now")) {
                    Task {
                        await viewModel.save()
                        session.persona = viewModel.selectedPersona
                        session.preferredLanguage = viewModel.preferredLanguage
                    }
                }
                .buttonStyle(HiAirGradientButtonStyle())
                .disabled(viewModel.loading)

                HiAirBrandMonoFooter()
                    .padding(.top, HiAirSpacing.md)
                }
                .hiAirContentWidth(for: width)
                .hiAirScreenPadding(for: width)
                .padding(.bottom, HiAirSpacing.xl)
            }
        }
        .hiAirPageBackground()
        .onAppear {
            if viewModel.userId.isEmpty {
                viewModel.userId = session.userId
            }
            if viewModel.accessToken.isEmpty {
                viewModel.accessToken = session.accessToken
            }
            if viewModel.profileId.isEmpty {
                viewModel.profileId = session.profileId
            }
            if let birth = session.dateOfBirth {
                viewModel.dateOfBirth = birth
            }
            if viewModel.selectedPersona != session.persona {
                viewModel.selectedPersona = session.persona
            }
            if viewModel.preferredLanguage != session.preferredLanguage {
                viewModel.preferredLanguage = session.preferredLanguage
            }
            viewModel.onEntitlementChanged = { entitlement in
                session.applyEntitlement(entitlement)
            }
            Task { await session.refreshEntitlement() }
            #if DEBUG
            if viewModel.plans.isEmpty {
                Task { await viewModel.loadPlans() }
            }
            #endif
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
        .onChange(of: viewModel.pushAlertsEnabled) { enabled in
            session.markChecklistItem("notifications", done: enabled)
        }
        .onChange(of: viewModel.preferredLanguage) { language in
            session.preferredLanguage = language
        }
        .sheet(isPresented: $showingGuide) {
            HiAirGuideView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showingAIGuide) {
            HiAirAIGuideView()
                .environmentObject(session)
        }
    }

    private static func localeIdentifier(for language: String) -> String {
        switch language.lowercased() {
        case "ru": return "ru_RU"
        case "es": return "es_ES"
        case "it": return "it_IT"
        case "fr": return "fr_FR"
        default: return "en_US"
        }
    }

    private func planLabel(_ plan: SubscriptionPlan) -> String {
        if let price = plan.priceUsd {
            return "\(plan.name) - \(String(format: "$%.2f", price))"
        }
        if let iosId = plan.iosProductId {
            return "\(plan.name) (\(iosId))"
        }
        return plan.name
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

private struct AIGuideAnswer {
    let titleKey: String
    let stepKeys: [String]
    let quickActions: [AIGuideQuickAction]
}

private enum AIGuideIntent {
    case onboarding
    case risk
    case planner
    case notifications
    case symptoms
    case account
    case fallback
}

private enum AIGuideQuickAction: String {
    case openDashboard
    case openPlanner
    case openInsights
    case openSymptoms
    case openNotifications
    case openAccount
    case openOnboarding

    var titleKey: String {
        switch self {
        case .openDashboard:
            return "ai_guide.action.open_dashboard"
        case .openPlanner:
            return "ai_guide.action.open_planner"
        case .openInsights:
            return "ai_guide.action.open_insights"
        case .openSymptoms:
            return "ai_guide.action.open_symptoms"
        case .openNotifications:
            return "ai_guide.action.open_notifications"
        case .openAccount:
            return "ai_guide.action.open_account"
        case .openOnboarding:
            return "ai_guide.action.open_onboarding"
        }
    }
}

private enum HiAirAIGuideEngine {
    static func answer(for question: String, lang: String) -> AIGuideAnswer {
        let normalized = normalizedText(question)
        let tokens = normalized.split(separator: " ").map(String.init)
        let language = normalizedLanguage(lang)

        let onboardingWords: [String]
        let riskWords: [String]
        let plannerWords: [String]
        let notificationWords: [String]
        let symptomsWords: [String]
        let accountWords: [String]

        switch language {
        case "es":
            onboardingWords = ["onboarding", "primer inicio", "empezar", "comenzar", "inicio", "registr", "cómo empezar", "como empezar"]
            riskWords = ["risk", "riesgo", "aqi", "pm2.5", "ozono", "calor", "humedad", "calidad del aire", "interpretar"]
            plannerWords = ["plan", "planner", "ventana segura", "ventanas seguras", "pronóstico", "pronostico", "hora", "paseo", "deporte", "ventilación", "ventilacion"]
            notificationWords = ["notificación", "notificacion", "notificaciones", "alerta", "push", "aviso", "morning briefing"]
            symptomsWords = ["síntoma", "sintoma", "síntomas", "sintomas", "insight", "insights", "registro", "diario"]
            accountWords = ["cuenta", "perfil", "privacidad", "borrar", "eliminar", "exportar", "login", "ajustes", "datos"]
        case "it":
            onboardingWords = ["onboarding", "primo avvio", "iniziare", "inizio", "registr", "come iniziare"]
            riskWords = ["risk", "rischio", "aqi", "pm2.5", "ozono", "calore", "umidita", "umidità", "qualita dell aria", "qualità dell aria"]
            plannerWords = ["piano", "planner", "finestra sicura", "finestre sicure", "previsione", "orario", "passeggi", "sport", "ventilazione"]
            notificationWords = ["notifica", "notifiche", "alert", "push", "avviso", "morning briefing"]
            symptomsWords = ["sintomo", "sintomi", "insight", "insights", "registro", "log"]
            accountWords = ["account", "profilo", "privacy", "elimina", "cancella", "esporta", "login", "impostazioni", "dati"]
        case "fr":
            onboardingWords = ["onboarding", "premier lancement", "demarrer", "démarrer", "commencer", "inscription", "comment commencer"]
            riskWords = ["risk", "risque", "aqi", "pm2.5", "ozone", "chaleur", "humidite", "humidité", "qualite de l air", "qualité de l air"]
            plannerWords = ["plan", "planner", "creneau sur", "créneau sûr", "creneaux surs", "créneaux sûrs", "prevision", "prévision", "horaire", "marche", "sport", "ventilation"]
            notificationWords = ["notification", "notifications", "alerte", "push", "avertissement", "morning briefing"]
            symptomsWords = ["symptome", "symptôme", "symptomes", "symptômes", "insight", "insights", "journal", "log"]
            accountWords = ["compte", "profil", "confidentialite", "confidentialité", "supprimer", "exporter", "connexion", "parametres", "paramètres", "donnees", "données"]
        case "ru":
            onboardingWords = ["онбординг", "первый запуск", "с чего начать", "как начать", "старт", "начать", "onboarding", "first run"]
            riskWords = ["риск", "aqi", "pm2.5", "озон", "качество воздуха", "heat index", "влажност", "как читать", "risk"]
            plannerWords = ["план", "safe window", "safe windows", "безопасн", "прогноз", "по часам", "прогул", "спорт", "проветр", "planner"]
            notificationWords = ["уведомл", "алерт", "push", "предупрежд", "утренний брифинг", "notification", "alert"]
            symptomsWords = ["симптом", "симптомы", "инсайт", "инсайты", "журнал", "лог", "symptom", "insight"]
            accountWords = ["аккаунт", "профил", "приват", "удал", "экспорт", "войти", "регистрац", "настройк", "account", "profile"]
        default:
            onboardingWords = ["onboarding", "first launch", "first run", "start", "where begin", "how to start", "get started", "как начать", "первый запуск"]
            riskWords = ["risk", "aqi", "pm2.5", "ozone", "heat index", "humidity", "air quality", "риск", "озон"]
            plannerWords = ["planner", "safe window", "safe windows", "hourly", "forecast", "walk", "sport", "ventilation", "план", "безопасн"]
            notificationWords = ["notification", "notifications", "alert", "push", "warning", "morning briefing", "уведомл", "алерт"]
            symptomsWords = ["symptom", "symptoms", "insight", "insights", "journal", "log", "симптом", "инсайт"]
            accountWords = ["account", "profile", "privacy", "delete", "export", "login", "sign", "settings", "аккаунт", "профил"]
        }

        let candidates: [(AIGuideIntent, [String])] = [
            (.onboarding, onboardingWords),
            (.risk, riskWords),
            (.planner, plannerWords),
            (.notifications, notificationWords),
            (.symptoms, symptomsWords),
            (.account, accountWords),
        ]

        let scored = candidates.map { intent, keywords in
            (intent, scoreIntent(normalized, tokens: tokens, keywords: keywords))
        }

        guard let best = scored.max(by: { lhs, rhs in
            if lhs.1 == rhs.1 {
                return priority(of: lhs.0) > priority(of: rhs.0)
            }
            return lhs.1 < rhs.1
        }), best.1 > 0 else {
            return answer(for: .fallback)
        }

        return answer(for: best.0)
    }

    private static func normalizedLanguage(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.hasPrefix("es") { return "es" }
        if lower.hasPrefix("it") { return "it" }
        if lower.hasPrefix("fr") { return "fr" }
        return lower.hasPrefix("en") ? "en" : "ru"
    }

    private static func normalizedText(_ raw: String) -> String {
        let lowered = raw.lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ". "))
        let mapped = lowered.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : " "
        }
        return String(mapped).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func scoreIntent(_ text: String, tokens: [String], keywords: [String]) -> Int {
        keywords.reduce(0) { partial, keyword in
            partial + scoreKeyword(text, tokens: tokens, keyword: keyword)
        }
    }

    private static func scoreKeyword(_ text: String, tokens: [String], keyword: String) -> Int {
        if keyword.contains(" ") {
            return text.contains(keyword) ? 3 : 0
        }
        if tokens.contains(where: { $0 == keyword || $0.hasPrefix(keyword) || keyword.hasPrefix($0) }) {
            return 2
        }
        return text.contains(keyword) ? 1 : 0
    }

    private static func priority(of intent: AIGuideIntent) -> Int {
        switch intent {
        case .onboarding:
            return 6
        case .risk:
            return 5
        case .planner:
            return 4
        case .notifications:
            return 3
        case .symptoms:
            return 2
        case .account:
            return 1
        case .fallback:
            return 0
        }
    }

    private static func answer(for intent: AIGuideIntent) -> AIGuideAnswer {
        switch intent {
        case .onboarding:
            return AIGuideAnswer(
                titleKey: "ai_guide.intent.onboarding.title",
                stepKeys: [
                    "ai_guide.intent.onboarding.step1",
                    "ai_guide.intent.onboarding.step2",
                    "ai_guide.intent.onboarding.step3",
                    "ai_guide.intent.onboarding.step4",
                ],
                quickActions: [.openOnboarding, .openDashboard]
            )
        case .risk:
            return AIGuideAnswer(
                titleKey: "ai_guide.intent.risk.title",
                stepKeys: [
                    "ai_guide.intent.risk.step1",
                    "ai_guide.intent.risk.step2",
                    "ai_guide.intent.risk.step3",
                    "ai_guide.intent.risk.step4",
                ],
                quickActions: [.openDashboard, .openPlanner]
            )
        case .planner:
            return AIGuideAnswer(
                titleKey: "ai_guide.intent.planner.title",
                stepKeys: [
                    "ai_guide.intent.planner.step1",
                    "ai_guide.intent.planner.step2",
                    "ai_guide.intent.planner.step3",
                    "ai_guide.intent.planner.step4",
                ],
                quickActions: [.openPlanner, .openDashboard]
            )
        case .notifications:
            return AIGuideAnswer(
                titleKey: "ai_guide.intent.notifications.title",
                stepKeys: [
                    "ai_guide.intent.notifications.step1",
                    "ai_guide.intent.notifications.step2",
                    "ai_guide.intent.notifications.step3",
                    "ai_guide.intent.notifications.step4",
                ],
                quickActions: [.openNotifications, .openDashboard]
            )
        case .symptoms:
            return AIGuideAnswer(
                titleKey: "ai_guide.intent.symptoms.title",
                stepKeys: [
                    "ai_guide.intent.symptoms.step1",
                    "ai_guide.intent.symptoms.step2",
                    "ai_guide.intent.symptoms.step3",
                    "ai_guide.intent.symptoms.step4",
                ],
                quickActions: [.openSymptoms, .openInsights]
            )
        case .account:
            return AIGuideAnswer(
                titleKey: "ai_guide.intent.account.title",
                stepKeys: [
                    "ai_guide.intent.account.step1",
                    "ai_guide.intent.account.step2",
                    "ai_guide.intent.account.step3",
                    "ai_guide.intent.account.step4",
                ],
                quickActions: [.openAccount, .openOnboarding]
            )
        case .fallback:
            return AIGuideAnswer(
                titleKey: "ai_guide.intent.fallback.title",
                stepKeys: [
                    "ai_guide.intent.fallback.step1",
                    "ai_guide.intent.fallback.step2",
                    "ai_guide.intent.fallback.step3",
                    "ai_guide.intent.fallback.step4",
                ],
                quickActions: [.openDashboard, .openPlanner, .openAccount]
            )
        }
    }
}

private struct AIGuideMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
    let quickActions: [AIGuideQuickAction]
}

private struct HiAirAIGuideView: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var messages: [AIGuideMessage] = []

    private var suggestions: [String] {
        [
            session.l("ai_guide.suggestion.onboarding"),
            session.l("ai_guide.suggestion.risk"),
            session.l("ai_guide.suggestion.safe_windows"),
            session.l("ai_guide.suggestion.notifications"),
            session.l("ai_guide.suggestion.symptoms"),
            session.l("ai_guide.suggestion.account"),
        ]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    AiryGuideAvatar(size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.l("ai_guide.title"))
                            .font(AuroraTokens.Typography.titleMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        Text(session.l("ai_guide.subtitle"))
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.tertiaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { message in
                                HStack(alignment: .top, spacing: 8) {
                                    if message.role == .assistant {
                                        AiryGuideAvatar(size: 28)
                                    } else {
                                        Spacer(minLength: 0)
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(message.role == .assistant ? session.l("ai_guide.assistant_label") : session.l("ai_guide.user_label"))
                                            .font(AuroraTokens.Typography.caption)
                                            .foregroundStyle(HiAirV2Theme.tertiaryText)
                                        Text(message.text)
                                            .font(AuroraTokens.Typography.bodyMD)
                                            .foregroundStyle(HiAirV2Theme.primaryText)
                                        if message.role == .assistant, !message.quickActions.isEmpty {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 8) {
                                                    ForEach(message.quickActions, id: \.rawValue) { action in
                                                        Button(session.l(action.titleKey)) {
                                                            applyQuickAction(action)
                                                        }
                                                        .font(AuroraTokens.Typography.caption)
                                                        .foregroundStyle(HiAirV2Theme.primaryText)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 6)
                                                        .hiAirChipSurface()
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    if message.role == .user {
                                        Circle()
                                            .fill(HiAirV2Theme.accentStart.opacity(0.5))
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(HiAirV2Theme.primaryText)
                                            )
                                    } else {
                                        Spacer(minLength: 0)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: message.role == .assistant ? .leading : .trailing)
                                .background(
                                    message.role == .assistant
                                    ? HiAirV2Theme.cardFill.opacity(0.95)
                                    : HiAirV2Theme.accentStart.opacity(0.22),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                    .onChange(of: messages.count) { _ in
                        guard let lastId = messages.last?.id else { return }
                        withAnimation(.easeOut(duration: AuroraTokens.Motion.fast)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                askQuestion(suggestion)
                            }
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .hiAirChipSurface()
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                HStack(spacing: 8) {
                    TextField(session.l("ai_guide.placeholder"), text: $question)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.send)
                        .onSubmit { askQuestion(question) }
                    Button(session.l("ai_guide.send")) {
                        askQuestion(question)
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .v2PageBackground()
            .navigationTitle(session.l("ai_guide.title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(session.l("ai_guide.clear")) {
                        resetConversation()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(session.l("common.close")) { dismiss() }
                }
            }
            .onAppear {
                if messages.isEmpty {
                    resetConversation()
                }
            }
        }
    }

    private func resetConversation() {
        let languageLabel = session.l("settings.language_\(displayLanguageCode(session.preferredLanguage))")
        messages = [
            AIGuideMessage(
                role: .assistant,
                text: "\(session.l("ai_guide.greeting"))\n\(session.l("ai_guide.language_hint")) \(languageLabel).",
                quickActions: [.openDashboard, .openPlanner, .openNotifications]
            )
        ]
    }

    private func displayLanguageCode(_ lang: String) -> String {
        let lower = lang.lowercased()
        if lower.hasPrefix("es") { return "es" }
        if lower.hasPrefix("it") { return "it" }
        if lower.hasPrefix("fr") { return "fr" }
        return lower.hasPrefix("en") ? "en" : "ru"
    }

    private func askQuestion(_ rawQuestion: String) {
        let normalized = String(rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines).prefix(320))
        guard !normalized.isEmpty else { return }
        question = ""
        messages.append(AIGuideMessage(role: .user, text: normalized, quickActions: []))

        let answer = HiAirAIGuideEngine.answer(for: normalized, lang: session.preferredLanguage)
        let rendered = renderAnswer(answer)
        messages.append(AIGuideMessage(role: .assistant, text: rendered, quickActions: answer.quickActions))
    }

    private func renderAnswer(_ answer: AIGuideAnswer) -> String {
        var lines: [String] = [session.l(answer.titleKey)]
        for (index, stepKey) in answer.stepKeys.enumerated() {
            lines.append("\(index + 1). \(session.l(stepKey))")
        }
        lines.append(session.l("ai_guide.followup"))
        return lines.joined(separator: "\n")
    }

    private func applyQuickAction(_ action: AIGuideQuickAction) {
        switch action {
        case .openDashboard:
            session.selectedTab = 0
        case .openPlanner:
            session.selectedTab = 1
        case .openInsights:
            session.selectedTab = 2
        case .openSymptoms:
            session.selectedTab = 3
        case .openNotifications, .openAccount:
            session.selectedTab = 4
        case .openOnboarding:
            session.showOnboardingFromSettings = true
        }
        dismiss()
    }
}

private struct AiryGuideAvatar: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            fallbackAvatar
            Image("hiair-ai-guide-avatar")
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(HiAirColors.Overlay.borderGlass, lineWidth: 1))
        .shadow(color: AuroraTokens.ColorPalette.info.opacity(0.36), radius: 10, x: 0, y: 4)
        .accessibilityHidden(true)
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            AuroraTokens.ColorPalette.info.opacity(0.85),
                            AuroraTokens.ColorPalette.ctaEnd.opacity(0.65),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .fill(HiAirColors.Overlay.strong)
                .frame(width: size * 0.72, height: size * 0.72)
                .offset(y: size * 0.06)
            Circle()
                .fill(HiAirColors.Overlay.avatarHighlight)
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: -size * 0.13, y: -size * 0.08)
            Circle()
                .fill(HiAirColors.Overlay.avatarHighlight)
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: size * 0.13, y: -size * 0.08)
            Capsule()
                .fill(HiAirColors.Overlay.avatarFeature)
                .frame(width: size * 0.28, height: size * 0.08)
                .offset(y: size * 0.08)
        }
        .frame(width: size, height: size)
    }
}

private struct HiAirGuideView: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) private var dismiss

    private var sections: [(title: String, body: String)] {
        [
            ("guide.what_is_title", "guide.what_is_body"),
            ("guide.problems_title", "guide.problems_body"),
            ("guide.for_whom_title", "guide.for_whom_body"),
            ("guide.read_dashboard_title", "guide.read_dashboard_body"),
            ("guide.risk_title", "guide.risk_body"),
            ("guide.metrics_title", "guide.metrics_body"),
            ("guide.hourly_title", "guide.hourly_body"),
            ("guide.safe_windows_title", "guide.safe_windows_body"),
            ("guide.symptoms_title", "guide.symptoms_body"),
            ("guide.notifications_title", "guide.notifications_body"),
            ("guide.high_risk_title", "guide.high_risk_body"),
            ("guide.not_doctor_title", "guide.not_doctor_body"),
            ("guide.faq_title", "guide.faq_body"),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.l(section.title))
                                .font(AuroraTokens.Typography.titleMD)
                                .foregroundStyle(HiAirV2Theme.primaryText)
                            Text(session.l(section.body))
                                .font(AuroraTokens.Typography.bodyMD)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                        }
                        .v2Card()
                    }
                }
                .padding(16)
            }
            .v2PageBackground()
            .navigationTitle(session.l("guide.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(session.l("common.close")) { dismiss() }
                }
            }
        }
    }
}
