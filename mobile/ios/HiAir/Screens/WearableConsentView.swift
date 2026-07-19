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
                    Text(String(format: session.l("wearable.health.build_label"), healthService.diagnostics().buildNumber))
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirV2Theme.tertiaryText)
                    HStack(spacing: 10) {
                        Button(session.l("wearable.consent.skip")) {
                            onComplete?()
                            if !fromOnboarding { dismiss() }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                        Button(working ? session.l("common.loading") : session.l("wearable.consent.connect")) {
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

    private func connect() async {
        working = true
        defer { working = false }
        guard healthService.isHealthDataAvailable() else {
            healthService.reportAuthorizationIssue("wearable.health.error.unavailable_device")
            healthService.reportConnectionState(.unavailable)
            showHealthPathHint = true
            return
        }
        if let issue = healthService.configurationIssueMessage() {
            healthService.reportAuthorizationIssue(issue)
            healthService.reportConnectionState(.unavailable)
            showHealthPathHint = true
            return
        }
        // Progressive consent: start with activity + sleep, then heart/recovery.
        healthService.setEnabledTiers([1, 2])
        let granted = await healthService.requestAuthorization(tiers: [1, 2])
        if granted {
            do {
                try await healthService.saveConsent(userId: session.userId, accessToken: session.accessToken)
                await healthService.syncHealthIntelligence(
                    userId: session.userId,
                    accessToken: session.accessToken,
                    profileId: session.profileId.isEmpty ? nil : session.profileId
                )
                await healthService.syncWearableHourlySummary(userId: session.userId, accessToken: session.accessToken)
            } catch {
                healthService.reportConnectionState(.syncFailed)
            }
            onComplete?()
            if !fromOnboarding { dismiss() }
            return
        }
        showHealthPathHint = true
        if healthService.connectionState != .permissionDenied {
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
                Text("\(session.l("wearable.dashboard.steps")): \(summary.stepsTotal ?? 0)")
                    .font(HiAirTypography.bodyMD)
                Text(heartRateLabel)
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
                if let load {
                    Text("\(session.l("wearable.dashboard.load_risk")): \(loadLevelLabel(load.level))")
                        .font(HiAirTypography.bodyMD)
                    if let first = load.explanations.first {
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
        default:
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
        if avg > 100 {
            return session.l("wearable.dashboard.hr_elevated")
        }
        return session.l("wearable.dashboard.hr_normal")
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
