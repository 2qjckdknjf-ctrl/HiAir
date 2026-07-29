import SwiftUI

struct WearableConsentView: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let fromOnboarding: Bool
    var onComplete: (() -> Void)?

    @StateObject private var healthService = HealthKitService.shared
    @State private var working = false
    @State private var showHealthPathHint = false

    var body: some View {
        HiAirAdaptiveLayout { width, mode in
            ScrollView {
                VStack(alignment: .leading, spacing: HiAirResponsiveSpacing.sectionSpacing(for: mode)) {
                    Text(session.l("wearable.consent.title"))
                        .font(AuroraTokens.Typography.displayLG)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Text(session.l("wearable.consent.body"))
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                    Text(session.l("wearable.consent.disclaimer"))
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirV2Theme.tertiaryText)
                    if showHealthPathHint {
                        if let errorText = session.lHealthKitError(healthService.lastAuthorizationError) {
                            Text(errorText)
                                .font(HiAirTypography.caption)
                                .foregroundStyle(AuroraTokens.ColorPalette.errorSoft)
                        }
                        Text(session.l("wearable.dashboard.health_path"))
                            .font(HiAirTypography.caption)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                        Button(session.l("wearable.dashboard.open_health")) {
                            HealthKitService.openHealthApp()
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                    }
                    if healthService.connectionState == .consentFailed {
                        Text(session.l("wearable.consent.failed"))
                            .font(HiAirTypography.caption)
                            .foregroundStyle(AuroraTokens.ColorPalette.errorSoft)
                    }
                    #if DEBUG
                    Text(String(format: session.l("wearable.health.build_label"), healthService.diagnostics().buildNumber))
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirV2Theme.tertiaryText)
                    #endif
                    HStack(spacing: 10) {
                        Button(session.l("wearable.consent.skip")) {
                            onComplete?()
                            if !fromOnboarding { dismiss() }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                        Button(connectButtonTitle) {
                            Task { await connect() }
                        }
                        .buttonStyle(HiAirGradientButtonStyle())
                        .disabled(working)
                    }
                }
                .v2Card()
                .hiAirContentWidth(for: width)
                .hiAirScreenPadding(for: width)
            }
        }
        .hiAirPageBackground()
    }

    private var connectButtonTitle: String {
        switch healthService.connectionState {
        case .consentSaving:
            return session.l("wearable.consent.saving")
        case .consentFailed:
            return session.l("wearable.consent.retry")
        case .systemAuthorized where working:
            return session.l("wearable.consent.saving")
        default:
            return working ? session.l("common.loading") : session.l("wearable.consent.connect")
        }
    }

    private func connect() async {
        working = true
        defer { working = false }
        ProductAnalytics.track("health_connect_started")
        guard healthService.isHealthDataAvailable() else {
            healthService.reportAuthorizationIssue("wearable.health.error.unavailable_device")
            healthService.reportConnectionState(.unavailable)
            showHealthPathHint = true
            ProductAnalytics.track("health_availability_checked", properties: ["available": "false"])
            return
        }
        ProductAnalytics.track("health_availability_checked", properties: ["available": "true"])
        if let issue = healthService.configurationIssueMessage() {
            healthService.reportAuthorizationIssue(issue)
            healthService.reportConnectionState(.unavailable)
            showHealthPathHint = true
            return
        }
        guard !session.userId.isEmpty, !session.accessToken.isEmpty else {
            healthService.reportAuthorizationIssue("wearable.health.error.generic|missing_session")
            showHealthPathHint = true
            return
        }
        // Request activity + heart + respiratory/temperature so Insights can use SpO2/temp when available.
        RuntimePerformanceProbe.begin("health_connect_ui")
        let userId = session.userId
        let accessToken = session.accessToken
        let profileId = session.profileId.isEmpty ? nil : session.profileId
        let granted = await healthService.requestAuthorization(tiers: [1, 2, 3], userId: userId)
        if granted {
            // Exit system wait immediately — durable consent is the Connected gate.
            RuntimePerformanceProbe.end("health_connect_ui", success: true)
            do {
                try await healthService.saveConsent(userId: userId, accessToken: accessToken)
            } catch {
                ProductAnalytics.track(
                    "health_connect_failed",
                    properties: [
                        "stage": "consent_save",
                        "error_type": String(describing: type(of: error)),
                    ]
                )
                showHealthPathHint = true
                return
            }
            guard session.userId == userId else { return }
            onComplete?()
            if !fromOnboarding { dismiss() }
            healthService.startBackgroundHealthSync(
                userId: userId,
                accessToken: accessToken,
                profileId: profileId
            )
            return
        }
        RuntimePerformanceProbe.end("health_connect_ui", success: false, errorCode: "denied")
        showHealthPathHint = true
        // Preserve timeout / sync-failed states — do not mislabel them as permission denied.
        switch healthService.connectionState {
        case .permissionDenied, .syncFailed, .partial, .dataUnavailable, .revokeFailed,
             .remoteRevokePending, .revoking, .consentFailed:
            break
        default:
            healthService.reportConnectionState(.permissionDenied)
        }
    }
}

struct WearableLoadCardView: View {
    @EnvironmentObject var session: AppSession
    let today: WearableTodayResponse?
    let connectionState: WearableConnectionState
    var onConnect: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l("wearable.dashboard.title"))
                .font(HiAirTypography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            content
        }
        .v2Card()
    }

    @ViewBuilder
    private var content: some View {
        switch connectionState {
        case .connected:
            if let summary = today?.dailySummary {
                let load = today?.personalLoad
                if let steps = summary.stepsTotal {
                    Text("\(session.l("wearable.dashboard.steps")): \(steps)")
                        .font(HiAirTypography.bodyMD)
                }
                Text(heartRateLabel)
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
                if let resting = summary.restingHeartRateAvg {
                    Text(String(format: session.l("wearable.dashboard.rhr_bpm"), Int(resting.rounded())))
                        .font(HiAirTypography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                }
                if let load {
                    Text("\(session.l("wearable.dashboard.load_risk")): \(loadLevelLabel(load.level))")
                        .font(HiAirTypography.bodyMD)
                    if let first = load.explanations.first, !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(first)
                            .font(HiAirTypography.caption)
                            .foregroundStyle(HiAirV2Theme.tertiaryText)
                    }
                }
            } else {
                Text(session.l("wearable.dashboard.unavailable"))
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
            }
        case .systemAuthorized, .consentSaving:
            Text(session.l("wearable.consent.saving"))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
        case .revoking, .remoteRevokePending:
            Text(session.l("wearable.consent.revoking"))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
        case .revokeFailed:
            Text(session.l("wearable.consent.revoke_failed"))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            Button(session.l("wearable.consent.retry"), action: onConnect)
                .buttonStyle(HiAirSecondaryButtonStyle())
        case .consentFailed:
            Text(session.l("wearable.consent.failed"))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            Button(session.l("wearable.consent.retry"), action: onConnect)
                .buttonStyle(HiAirSecondaryButtonStyle())
        case .permissionDenied:
            Text(session.l("wearable.dashboard.denied"))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            Text(session.l("wearable.dashboard.health_path"))
                .font(HiAirTypography.caption)
                .foregroundStyle(HiAirV2Theme.tertiaryText)
            Button(session.l("wearable.dashboard.open_health"), action: onOpenSettings)
                .buttonStyle(HiAirSecondaryButtonStyle())
        case .dataUnavailable, .syncFailed:
            Text(session.l("wearable.dashboard.unavailable"))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
        case .notConnected, .permissionRequested, .unavailable, .partial:
            Text(session.l("wearable.dashboard.not_connected"))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            Button(session.l("wearable.consent.connect"), action: onConnect)
                .buttonStyle(HiAirSecondaryButtonStyle())
        }
    }

    private var heartRateLabel: String {
        guard let avg = today?.dailySummary?.heartRateAvg else {
            return session.l("wearable.dashboard.hr_unknown")
        }
        let bpm = Int(avg.rounded())
        if avg > 100 {
            return String(format: session.l("wearable.dashboard.hr_elevated_bpm"), bpm)
        }
        return String(format: session.l("wearable.dashboard.hr_bpm"), bpm)
    }

    private func loadLevelLabel(_ level: String) -> String {
        switch level {
        case "low": return session.l("wearable.load.low")
        case "moderate": return session.l("wearable.load.moderate")
        case "elevated", "high": return session.l("wearable.load.elevated")
        default: return session.l("wearable.load.none")
        }
    }
}
