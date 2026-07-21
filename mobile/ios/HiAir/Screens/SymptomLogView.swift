import SwiftUI

@MainActor
final class SymptomLogViewModel: ObservableObject {
    @Published var taxonomy: SymptomTaxonomyDTO?
    @Published var selectedType: String?
    @Published var severity = 2
    @Published var locationContext = "unspecified"
    @Published var frequency = "unspecified"
    @Published var durationMinutes: Int = 0
    @Published var ongoing = false
    @Published var suspectedTrigger = ""
    @Published var activityAtOnset = "unspecified"
    @Published var hydrationState = "unspecified"
    @Published var medicationTaken = false
    @Published var note = ""
    @Published var searchText = ""
    @Published var selectedCategory: String?
    @Published var favorites: [String] = []
    @Published var statusText = ""
    @Published var safetyNotice: String?
    @Published var loading = false
    @Published var taxonomyFailed = false

    private let apiClient = APIClient.live()
    private let defaultFavoriteTypes = ["cough", "headache", "fatigue", "itchy_eyes", "shortness_of_breath"]
    private let favoritesKey = "symptoms.favorites.v1"

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        favorites = stored
    }

    func loadTaxonomy(language: String) async {
        do {
            taxonomy = try await apiClient.fetchSymptomTaxonomy(language: language)
            taxonomyFailed = false
            let available = Set((taxonomy?.categories ?? []).flatMap(\.symptoms).map(\.symptomType))
            if favorites.isEmpty {
                favorites = defaultFavoriteTypes.filter { available.contains($0) }
                persistFavorites()
            } else {
                favorites = favorites.filter { available.contains($0) }
                persistFavorites()
            }
        } catch {
            taxonomy = nil
            taxonomyFailed = true
        }
    }

    func toggleFavorite(_ type: String) {
        if let index = favorites.firstIndex(of: type) {
            favorites.remove(at: index)
        } else {
            favorites.append(type)
        }
        persistFavorites()
    }

    private func persistFavorites() {
        UserDefaults.standard.set(favorites, forKey: favoritesKey)
    }

    var filteredCategories: [SymptomCategoryDTO] {
        guard let taxonomy else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return taxonomy.categories.compactMap { category in
            if let selectedCategory, selectedCategory != category.id { return nil }
            let symptoms = category.symptoms.filter { item in
                query.isEmpty || item.label.lowercased().contains(query)
            }
            guard !symptoms.isEmpty else { return nil }
            return SymptomCategoryDTO(id: category.id, label: category.label, symptoms: symptoms)
        }
    }

    func quickLog(
        profileId: String,
        symptomType: String,
        userId: String,
        accessToken: String,
        language: String
    ) async {
        selectedType = symptomType
        await submit(
            profileId: profileId,
            userId: userId,
            accessToken: accessToken,
            language: language
        )
    }

    func submit(profileId: String, userId: String, accessToken: String, language: String) async {
        guard let selectedType else {
            statusText = HiAirL10n.t("symptoms.select_first", lang: language)
            return
        }
        loading = true
        defer { loading = false }
        do {
            let result = try await apiClient.createComprehensiveSymptom(
                ComprehensiveSymptomPayload(
                    profileId: profileId,
                    symptomType: selectedType,
                    severity: severity,
                    onsetAt: nil,
                    durationMinutes: durationMinutes > 0 ? durationMinutes : nil,
                    ongoing: ongoing,
                    frequency: frequency == "unspecified" ? nil : frequency,
                    bodyContext: nil,
                    suspectedTrigger: suspectedTrigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : suspectedTrigger.trimmingCharacters(in: .whitespacesAndNewlines),
                    activityAtOnset: activityAtOnset == "unspecified" ? nil : activityAtOnset,
                    locationContext: locationContext == "unspecified" ? nil : locationContext,
                    hydrationState: hydrationState == "unspecified" ? nil : hydrationState,
                    medicationTaken: medicationTaken ? true : nil,
                    note: note.isEmpty ? nil : note,
                    timezone: TimeZone.current.identifier,
                    customLabel: nil
                ),
                userId: userId,
                accessToken: accessToken,
                language: language
            )
            statusText = HiAirL10n.t("symptoms.quick_saved", lang: language)
            safetyNotice = result.safetyNotice
            note = ""
            suspectedTrigger = ""
            ProductAnalytics.track("symptom_logged", properties: ["mode": "comprehensive"])
        } catch {
            statusText = HiAirL10n.t("symptoms.save_failed", lang: language)
        }
    }
}

struct SymptomLogView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = SymptomLogViewModel()

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 8)]

    var body: some View {
        HiAirAdaptiveLayout { width, mode in
            ScrollView {
                VStack(alignment: .leading, spacing: HiAirResponsiveSpacing.sectionSpacing(for: mode)) {
                    Text(session.l("symptoms.title"))
                        .font(AuroraTokens.Typography.displayLG)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                        .accessibilityAddTraits(.isHeader)

                    Text(session.l("symptoms.subtitle"))
                        .font(AuroraTokens.Typography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)

                    if let notice = viewModel.taxonomy?.safetyNotice {
                        Text(notice)
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                            .padding(12)
                            .background(HiAirColors.Overlay.subtle, in: RoundedRectangle(cornerRadius: 12))
                    }

                    if session.profileId.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.l("symptoms.empty.title"))
                                .font(AuroraTokens.Typography.titleMD)
                            Text(session.l("symptoms.empty.body"))
                                .font(AuroraTokens.Typography.bodyMD)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Button(session.l("planner.empty.no_profile.cta")) {
                                Task { _ = await session.ensureProfileIdIfNeeded() }
                            }
                            .buttonStyle(HiAirSecondaryButtonStyle())
                        }
                        .v2Card()
                    }

                    if viewModel.taxonomyFailed {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.l("symptoms.taxonomy_failed"))
                                .font(AuroraTokens.Typography.bodyMD)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                            Button(session.l("common.retry")) {
                                Task { await viewModel.loadTaxonomy(language: session.preferredLanguage) }
                            }
                            .buttonStyle(HiAirSecondaryButtonStyle())
                        }
                        .v2Card()
                    }

                    if !viewModel.favorites.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(session.l("symptoms.favorites"))
                                .font(AuroraTokens.Typography.titleMD)
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                                ForEach(viewModel.favorites, id: \.self) { type in
                                    Button {
                                        Task {
                                            await viewModel.quickLog(
                                                profileId: session.profileId,
                                                symptomType: type,
                                                userId: session.userId,
                                                accessToken: session.accessToken,
                                                language: session.preferredLanguage
                                            )
                                        }
                                    } label: {
                                        Text(labelFor(type))
                                            .font(AuroraTokens.Typography.bodyMD)
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                            .padding(.horizontal, 10)
                                            .background(HiAirColors.Cta.gradientStart.opacity(0.22), in: Capsule())
                                    }
                                }
                            }
                        }
                        .v2Card()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        TextField(session.l("symptoms.search"), text: $viewModel.searchText)
                            .textFieldStyle(.roundedBorder)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                filterChip(session.l("symptoms.all_categories"), id: nil)
                                ForEach(viewModel.taxonomy?.categories ?? [], id: \.id) { category in
                                    filterChip(category.label, id: category.id)
                                }
                            }
                        }
                    }
                    .v2Card()

                    ForEach(viewModel.filteredCategories) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.label)
                                .font(AuroraTokens.Typography.titleMD)
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                                ForEach(category.symptoms) { item in
                                    HStack(spacing: 4) {
                                        Button {
                                            viewModel.selectedType = item.symptomType
                                            if item.redFlag {
                                                viewModel.safetyNotice = viewModel.taxonomy?.safetyNotice
                                            }
                                        } label: {
                                            Text(item.redFlag ? "⚠︎ \(item.label)" : item.label)
                                                .font(AuroraTokens.Typography.bodyMD)
                                                .foregroundStyle(
                                                    viewModel.selectedType == item.symptomType
                                                        ? HiAirV2Theme.primaryText
                                                        : HiAirV2Theme.secondaryText
                                                )
                                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                                .padding(.horizontal, 8)
                                        }
                                        Button {
                                            viewModel.toggleFavorite(item.symptomType)
                                        } label: {
                                            Image(systemName: viewModel.favorites.contains(item.symptomType) ? "star.fill" : "star")
                                                .font(.caption)
                                                .foregroundStyle(HiAirV2Theme.tertiaryText)
                                                .frame(width: 36, height: 44)
                                        }
                                        .accessibilityLabel(session.l("symptoms.favorites"))
                                    }
                                    .background(
                                        (
                                            viewModel.selectedType == item.symptomType
                                                ? HiAirColors.Cta.gradientStart.opacity(0.28)
                                                : HiAirColors.Overlay.subtle
                                        ),
                                        in: Capsule()
                                    )
                                }
                            }
                        }
                        .v2Card()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(session.l("symptoms.severity"))
                            .font(AuroraTokens.Typography.bodyMD)
                        Text(severityCaption(viewModel.severity))
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.tertiaryText)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { value in
                                Button {
                                    viewModel.severity = value
                                } label: {
                                    Text("\(value)")
                                        .frame(width: 40, height: 40)
                                        .background(
                                            viewModel.severity == value
                                                ? HiAirColors.Cta.gradientStart.opacity(0.35)
                                                : HiAirColors.Overlay.subtle,
                                            in: Circle()
                                        )
                                }
                                .accessibilityLabel("\(session.l("symptoms.severity")) \(value), \(severityCaption(value))")
                            }
                        }
                        Picker(session.l("symptoms.location"), selection: $viewModel.locationContext) {
                            Text(session.l("symptoms.location.any")).tag("unspecified")
                            Text(session.l("symptoms.location.indoors")).tag("indoors")
                            Text(session.l("symptoms.location.outdoors")).tag("outdoors")
                        }
                        .pickerStyle(.segmented)
                        Picker(session.l("symptoms.frequency"), selection: $viewModel.frequency) {
                            Text(session.l("symptoms.frequency.any")).tag("unspecified")
                            Text(session.l("symptoms.frequency.once")).tag("once")
                            Text(session.l("symptoms.frequency.intermittent")).tag("intermittent")
                            Text(session.l("symptoms.frequency.constant")).tag("constant")
                        }
                        .pickerStyle(.menu)
                        Picker(session.l("symptoms.duration"), selection: $viewModel.durationMinutes) {
                            Text(session.l("symptoms.duration.any")).tag(0)
                            Text(session.l("symptoms.duration.15m")).tag(15)
                            Text(session.l("symptoms.duration.1h")).tag(60)
                            Text(session.l("symptoms.duration.3h")).tag(180)
                            Text(session.l("symptoms.duration.day")).tag(1440)
                        }
                        .pickerStyle(.menu)
                        Toggle(session.l("symptoms.ongoing"), isOn: $viewModel.ongoing)
                        Picker(session.l("symptoms.activity"), selection: $viewModel.activityAtOnset) {
                            Text(session.l("symptoms.activity.any")).tag("unspecified")
                            Text(session.l("symptoms.activity.rest")).tag("rest")
                            Text(session.l("symptoms.activity.walk")).tag("walk")
                            Text(session.l("symptoms.activity.exercise")).tag("exercise")
                            Text(session.l("symptoms.activity.work")).tag("work")
                            Text(session.l("symptoms.activity.sleep")).tag("sleep")
                        }
                        .pickerStyle(.menu)
                        Picker(session.l("symptoms.hydration"), selection: $viewModel.hydrationState) {
                            Text(session.l("symptoms.hydration.any")).tag("unspecified")
                            Text(session.l("symptoms.hydration.low")).tag("low")
                            Text(session.l("symptoms.hydration.ok")).tag("adequate")
                            Text(session.l("symptoms.hydration.high")).tag("high")
                        }
                        .pickerStyle(.menu)
                        Toggle(session.l("symptoms.medication"), isOn: $viewModel.medicationTaken)
                        TextField(session.l("symptoms.trigger_optional"), text: $viewModel.suspectedTrigger)
                            .textFieldStyle(.roundedBorder)
                        TextField(session.l("symptoms.note_optional"), text: $viewModel.note, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                        if let safety = viewModel.safetyNotice {
                            Text(safety)
                                .font(AuroraTokens.Typography.caption)
                                .foregroundStyle(AuroraTokens.ColorPalette.errorSoft)
                        }
                    }
                    .v2Card()

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
                    .disabled(viewModel.loading || session.profileId.isEmpty || viewModel.selectedType == nil)
                    .frame(minHeight: 48)

                    if !viewModel.statusText.isEmpty {
                        Text(viewModel.statusText)
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                    }
                }
                .hiAirContentWidth(for: width)
                .hiAirScreenPadding(for: width)
                .padding(.bottom, HiAirSpacing.xl)
            }
        }
        .hiAirPageBackground()
        .task {
            _ = await session.ensureProfileIdIfNeeded()
            await viewModel.loadTaxonomy(language: session.preferredLanguage)
        }
    }

    private func filterChip(_ label: String, id: String?) -> some View {
        Button {
            viewModel.selectedCategory = id
        } label: {
            Text(label)
                .font(AuroraTokens.Typography.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    viewModel.selectedCategory == id
                        ? HiAirColors.Cta.gradientStart.opacity(0.3)
                        : HiAirColors.Overlay.subtle,
                    in: Capsule()
                )
        }
    }

    private func labelFor(_ type: String) -> String {
        for category in viewModel.taxonomy?.categories ?? [] {
            if let item = category.symptoms.first(where: { $0.symptomType == type }) {
                return item.label
            }
        }
        return session.l("symptoms.unknown")
    }

    private func severityCaption(_ value: Int) -> String {
        switch value {
        case 1, 2:
            return session.l("symptoms.severity.mild")
        case 3:
            return session.l("symptoms.severity.moderate")
        default:
            return session.l("symptoms.severity.severe")
        }
    }
}
