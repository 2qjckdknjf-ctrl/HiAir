import SwiftUI

@MainActor
final class SymptomLogViewModel: ObservableObject {
    @Published var cough = false
    @Published var wheeze = false
    @Published var headache = false
    @Published var fatigue = false
    @Published var sleepQuality = 3
    @Published var quickIntensity = 2
    @Published var statusText = "-"
    @Published var loading = false

    private let apiClient = APIClient.live()

    func submit(profileId: String, userId: String, accessToken: String, language: String) async {
        loading = true
        defer { loading = false }
        let payload = SymptomLogRequest(
            profileId: profileId,
            symptom: SymptomInput(
                cough: cough,
                wheeze: wheeze,
                headache: headache,
                fatigue: fatigue,
                sleepQuality: sleepQuality
            )
        )
        do {
            let result = try await apiClient.logSymptom(
                payload,
                userId: userId,
                accessToken: accessToken
            )
            statusText = "\(HiAirL10n.t("symptoms.saved_at", lang: language)) \(result.timestampUtc)"
            ProductAnalytics.track("symptom_logged", properties: ["mode": "form"])
        } catch {
            statusText = HiAirL10n.t("symptoms.save_failed", lang: language)
        }
    }

    func quickLog(
        profileId: String,
        symptomType: String,
        userId: String,
        accessToken: String,
        language: String
    ) async {
        loading = true
        defer { loading = false }
        do {
            try await apiClient.createQuickSymptom(
                AirSymptomCreateRequest(
                    profileId: profileId,
                    symptomType: symptomType,
                    intensity: quickIntensity,
                    note: nil
                ),
                userId: userId,
                accessToken: accessToken
            )
            statusText = HiAirL10n.t("symptoms.quick_saved", lang: language)
            ProductAnalytics.track("symptom_logged", properties: ["mode": "quick"])
        } catch {
            statusText = HiAirL10n.t("symptoms.quick_failed", lang: language)
        }
    }
}

struct SymptomLogView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = SymptomLogViewModel()

    var body: some View {
        HiAirAdaptiveLayout { width, mode in
            ScrollView {
                VStack(alignment: .leading, spacing: HiAirResponsiveSpacing.sectionSpacing(for: mode)) {
                Text(session.l("common.city_updated"))
                    .font(AuroraTokens.Typography.caption)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                Text(session.l("symptoms.title"))
                    .font(AuroraTokens.Typography.displayLG)
                    .foregroundStyle(HiAirV2Theme.primaryText)

                Text(session.l("symptoms.subtitle"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                Text(session.l("symptoms.streak"))
                    .font(AuroraTokens.Typography.caption)
                    .foregroundStyle(HiAirV2Theme.tertiaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(HiAirColors.Overlay.subtle, in: Capsule())

                if session.profileId.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.l("symptoms.empty.title"))
                            .font(AuroraTokens.Typography.titleMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        Text(session.l("symptoms.empty.body"))
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                        Button(session.l("planner.empty.no_profile.cta")) {
                            Task {
                                _ = await session.ensureProfileIdIfNeeded()
                            }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                        .tint(HiAirV2Theme.accentStart)
                    }
                    .v2Card()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("symptoms.title"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    HStack(spacing: 8) {
                        symptomPill("💨 \(session.l("symptoms.cough"))", isOn: $viewModel.cough)
                        symptomPill("🫁 \(session.l("symptoms.wheeze"))", isOn: $viewModel.wheeze)
                    }
                    HStack(spacing: 8) {
                        symptomPill("🤕 \(session.l("symptoms.headache"))", isOn: $viewModel.headache)
                        symptomPill("😮‍💨 \(session.l("symptoms.fatigue"))", isOn: $viewModel.fatigue)
                    }
                }
                .v2Card()

                VStack(alignment: .leading, spacing: 10) {
                    Text(session.l("symptoms.sleep_quality"))
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                viewModel.sleepQuality = value
                            } label: {
                                Text("\(value)")
                                    .font(AuroraTokens.Typography.caption.weight(.semibold))
                                    .foregroundStyle(viewModel.sleepQuality == value ? HiAirV2Theme.primaryText : HiAirV2Theme.secondaryText)
                                    .frame(width: 34, height: 28)
                                    .background(
                                        (viewModel.sleepQuality == value ? HiAirColors.Cta.gradientStart.opacity(0.35) : HiAirColors.Overlay.subtle),
                                        in: Capsule()
                                    )
                            }
                        }
                    }
                    Stepper("\(session.l("symptoms.quick_intensity")): \(viewModel.quickIntensity)", value: $viewModel.quickIntensity, in: 1...5)
                }
                .foregroundStyle(HiAirV2Theme.primaryText)
                .v2Card()

                HStack(spacing: 10) {
                    Button(session.l("symptoms.quick_breath")) {
                        Task {
                            await viewModel.quickLog(
                                profileId: session.profileId,
                                symptomType: "breath_discomfort",
                                userId: session.userId,
                                accessToken: session.accessToken,
                                language: session.preferredLanguage
                            )
                        }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())

                    Button(session.l("symptoms.quick_headache")) {
                        Task {
                            await viewModel.quickLog(
                                profileId: session.profileId,
                                symptomType: "headache",
                                userId: session.userId,
                                accessToken: session.accessToken,
                                language: session.preferredLanguage
                            )
                        }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                }
                .tint(HiAirV2Theme.accentStart)

                Button(viewModel.loading ? session.l("symptoms.saving") : session.l("symptoms.submit")) {
                    Task {
                        await viewModel.submit(
                            profileId: session.profileId,
                            userId: session.userId,
                            accessToken: session.accessToken,
                            language: session.preferredLanguage
                        )
                    }
                }
                .buttonStyle(HiAirGradientButtonStyle())
                .disabled(viewModel.loading || session.profileId.isEmpty)

                Text(viewModel.statusText)
                    .font(AuroraTokens.Typography.caption)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
            }
            .hiAirContentWidth(for: width)
            .hiAirScreenPadding(for: width)
            .padding(.bottom, HiAirSpacing.xl)
            }
        }
        .hiAirPageBackground()
        .onAppear {
            Task { _ = await session.ensureProfileIdIfNeeded() }
        }
    }

    private func symptomPill(_ label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(label)
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(isOn.wrappedValue ? HiAirV2Theme.primaryText : HiAirV2Theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    (isOn.wrappedValue ? HiAirColors.Cta.gradientStart.opacity(0.26) : HiAirColors.Overlay.subtle),
                    in: Capsule()
                )
        }
    }
}
