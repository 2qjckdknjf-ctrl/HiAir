import SwiftUI
import CoreLocation
import UserNotifications

struct OnboardingView: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let fromSettings: Bool
    @State private var step = 0
    @State private var personaSelection = "adult"
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @StateObject private var permissionCoordinator = OnboardingPermissionCoordinator()
    @StateObject private var healthService = HealthKitService.shared

    init(fromSettings: Bool = false) {
        self.fromSettings = fromSettings
    }

    private var isLastStep: Bool { step == 6 }
    private var canGoBack: Bool { step > 0 }

    var body: some View {
        HiAirAdaptiveLayout { width, mode in
            ScrollView {
                VStack(alignment: .leading, spacing: HiAirResponsiveSpacing.sectionSpacing(for: mode)) {
                if step == 0 {
                    HiAirBrandHeader(showOrb: true, orbSize: HiAirScreenMetrics.heroOrbSize(for: width) * 0.6)
                        .padding(.bottom, HiAirSpacing.xs)
                }

                HStack {
                    Spacer()
                    if fromSettings {
                        Button(session.l("common.close")) { dismiss() }
                            .font(HiAirTypography.caption)
                            .foregroundStyle(HiAirV2Theme.tertiaryText)
                    }
                }

                Group {
                    switch step {
                    case 0:
                        onboardingIntro
                    case 1:
                        onboardingProblems
                    case 2:
                        onboardingPersona
                    case 3:
                        onboardingWhatToWatch
                    case 4:
                        onboardingPermissions
                    case 5:
                        onboardingHealth
                    default:
                        onboardingDone
                    }
                }
                .v2Card()

                HStack(spacing: 10) {
                    if canGoBack {
                        Button(session.l("onboarding.back")) {
                            step = max(step - 1, 0)
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                    }
                    Button(primaryButtonTitle) {
                        Task { await handlePrimaryAction() }
                    }
                    .buttonStyle(HiAirGradientButtonStyle())
                }
            }
            .hiAirContentWidth(for: width)
            .hiAirScreenPadding(for: width)
            .padding(.bottom, HiAirSpacing.xl)
            }
        }
        .hiAirPageBackground()
        .onAppear {
            personaSelection = session.persona
            if step == 0 && !fromSettings {
                ProductAnalytics.track("onboarding_started")
            }
        }
    }

    private var primaryButtonTitle: String {
        if step == 0 {
            return session.l("onboarding.start")
        }
        if step == 4 {
            return session.l("onboarding.permissions.allow")
        }
        if step == 5 {
            return session.l("wearable.consent.skip")
        }
        if isLastStep {
            return session.l("onboarding.open_forecast")
        }
        return session.l("onboarding.next")
    }

    private func handlePrimaryAction() async {
        if step == 4 {
            await permissionCoordinator.requestAll()
            step += 1
            return
        }
        if step == 5 {
            step += 1
            return
        }
        if isLastStep {
            session.persona = personaSelection
            session.dateOfBirth = dateOfBirth
            session.finishOnboarding()
            if fromSettings {
                dismiss()
            }
            return
        }
        step += 1
    }

    private var onboardingIntro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l("onboarding.step1.title"))
                .font(AuroraTokens.Typography.displayLG)
                .foregroundStyle(HiAirV2Theme.primaryText)
            Text(session.l("onboarding.step1.body"))
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
        }
    }

    private var onboardingProblems: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l("onboarding.step2.title"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            problemRow("onboarding.problem.heat")
            problemRow("onboarding.problem.pm25")
            problemRow("onboarding.problem.ozone")
            problemRow("onboarding.problem.sensitive")
            problemRow("onboarding.problem.outdoor")
        }
    }

    private var onboardingPersona: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l("onboarding.step3.title"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            Text(session.l("onboarding.date_of_birth.title"))
                .font(AuroraTokens.Typography.bodyMD.weight(.semibold))
                .foregroundStyle(HiAirV2Theme.primaryText)
            Text(session.l("onboarding.date_of_birth.body"))
                .font(AuroraTokens.Typography.caption)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            DatePicker(
                session.l("settings.date_of_birth"),
                selection: $dateOfBirth,
                in: ...Date(),
                displayedComponents: .date
            )
            .environment(\.locale, Locale(identifier: session.preferredLanguage == "ru" ? "ru_RU" : "en_US"))
            personaOption("adult", key: "onboarding.for_self")
            personaOption("child", key: "onboarding.for_child")
            personaOption("elderly", key: "onboarding.for_elderly")
            personaOption("asthma", key: "onboarding.for_asthma")
            personaOption("allergy", key: "onboarding.for_allergy")
            personaOption("runner", key: "onboarding.for_runner")
            personaOption("worker", key: "onboarding.for_worker")
        }
    }

    private var onboardingWhatToWatch: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l("onboarding.step4.title"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            problemRow("onboarding.look.risk")
            problemRow("onboarding.look.hourly")
            problemRow("onboarding.look.recommendations")
            problemRow("onboarding.look.notifications")
        }
    }

    private var onboardingPermissions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.l("onboarding.step5.title"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            VStack(alignment: .leading, spacing: 6) {
                Text(session.l("onboarding.permissions.location.title"))
                    .font(AuroraTokens.Typography.bodyMD.weight(.semibold))
                    .foregroundStyle(HiAirV2Theme.primaryText)
                Text(session.l("onboarding.permissions.location.body"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(session.l("onboarding.permissions.notifications.title"))
                    .font(AuroraTokens.Typography.bodyMD.weight(.semibold))
                    .foregroundStyle(HiAirV2Theme.primaryText)
                Text(session.l("onboarding.permissions.notifications.body"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
            }
            Button(session.l("onboarding.permissions.later")) {
                step += 1
            }
            .buttonStyle(HiAirSecondaryButtonStyle())
        }
    }

    private var onboardingHealth: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.l("wearable.consent.title"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            Text(session.l("wearable.consent.body"))
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            Text(session.l("wearable.consent.disclaimer"))
                .font(AuroraTokens.Typography.caption)
                .foregroundStyle(HiAirV2Theme.tertiaryText)
            Button(session.l("wearable.consent.connect")) {
                Task {
                    guard healthService.isHealthDataAvailable() else {
                        step += 1
                        return
                    }
                    if healthService.configurationIssueMessage() != nil {
                        step += 1
                        return
                    }
                    if await healthService.requestAuthorization(),
                       !session.userId.isEmpty, !session.accessToken.isEmpty {
                        try? await healthService.saveConsent(userId: session.userId, accessToken: session.accessToken)
                        await healthService.syncWearableDailySummary(userId: session.userId, accessToken: session.accessToken)
                    }
                    step += 1
                }
            }
            .buttonStyle(HiAirGradientButtonStyle())
        }
    }

    private var onboardingDone: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l("onboarding.step6.title"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            Text(session.l("onboarding.step6.body"))
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
        }
    }

    private func problemRow(_ key: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HiAirV2Theme.accentStart)
                .font(.caption)
                .padding(.top, 2)
            Text(session.l(key))
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            Spacer()
        }
    }

    private func personaOption(_ persona: String, key: String) -> some View {
        Button {
            personaSelection = persona
        } label: {
            HStack {
                Text(session.l(key))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                Spacer()
                if personaSelection == persona {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(HiAirV2Theme.accentStart)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

final class OnboardingPermissionCoordinator: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestAll() async {
        locationManager.requestWhenInUseAuthorization()
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }
}
