import Foundation
import SwiftUI

enum SymptomCatalogPhase: Equatable {
    case idle
    case loading
    case loaded
    case failed
    case offlineCached
}

@MainActor
final class SymptomLogViewModel: ObservableObject {
    @Published var taxonomy: SymptomTaxonomyDTO?
    @Published var catalogPhase: SymptomCatalogPhase = .idle
    @Published var selectedType: String?
    @Published var severity = 2
    @Published var onsetDate = Date()
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
    @Published var showEntrySheet = false
    @Published var showAdvancedFields = false
    @Published var showCustomSheet = false
    @Published var customLabel = ""
    @Published var expandedCategoryIDs: Set<String> = []
    @Published var favorites: [String] = []
    @Published var recents: [String] = []
    @Published var history: [SymptomHistoryItem] = []
    @Published var editingEntryId: String?
    @Published var statusText = ""
    @Published var safetyNotice: String?
    @Published var loading = false
    @Published var usingCachedCatalog = false
    @Published var pendingOfflineSave = false

    private let apiClient = APIClient.live()
    private let defaultFavoriteTypes = ["cough", "headache", "fatigue", "itchy_eyes", "shortness_of_breath"]
    private let favoritesKey = "symptoms.favorites.v1"
    private let recentsKey = "symptoms.recents.v1"
    private let taxonomyCacheKey = "symptoms.taxonomy.cache.v1"
    private let taxonomySchemaVersion = 1
    private let offlineDraftKey = "symptoms.offline.draft.v1"
    private var taxonomyLoadGeneration = 0
    private var searchDebounceTask: Task<Void, Never>?
    private var debouncedSearch = ""
    private var activeIdempotencyKey: String?
    private var didTrackScreenOpen = false

    init() {
        favorites = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        recents = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        if let cached = loadCachedTaxonomy() {
            taxonomy = cached
            catalogPhase = .offlineCached
            usingCachedCatalog = true
        }
    }

    var taxonomyFailed: Bool { catalogPhase == .failed }

    func onScreenOpened() {
        guard !didTrackScreenOpen else { return }
        didTrackScreenOpen = true
        ProductAnalytics.track("symptom_screen_opened", properties: [
            "profile_present": taxonomy == nil ? "unknown" : "yes",
        ])
    }

    func loadTaxonomy(language: String, profilePresent: Bool, forceNetwork: Bool = false) async {
        taxonomyLoadGeneration += 1
        let generation = taxonomyLoadGeneration
        let retryNumber = forceNetwork ? 1 : 0

        if taxonomy == nil {
            catalogPhase = .loading
        }

        ProductAnalytics.track("taxonomy_load_started", properties: [
            "endpoint": "symptoms_taxonomy",
            "retry": String(retryNumber),
            "profile_present": profilePresent ? "yes" : "no",
        ])

        do {
            let fetched = try await apiClient.fetchSymptomTaxonomy(language: language)
            guard generation == taxonomyLoadGeneration else { return }

            let total = fetched.categories.reduce(0) { $0 + $1.symptoms.count }
            if total == 0 {
                catalogPhase = .failed
                ProductAnalytics.track("taxonomy_load_failed", properties: [
                    "endpoint": "symptoms_taxonomy",
                    "safe_error": "empty_catalog",
                    "retry": String(retryNumber),
                    "profile_present": profilePresent ? "yes" : "no",
                ])
                return
            }

            taxonomy = fetched
            persistTaxonomyCache(fetched)
            usingCachedCatalog = false
            catalogPhase = .loaded
            syncFavoritesWithCatalog()
            if expandedCategoryIDs.isEmpty, let first = fetched.categories.first?.id {
                expandedCategoryIDs = [first]
            }
            ProductAnalytics.track("taxonomy_load_succeeded", properties: [
                "endpoint": "symptoms_taxonomy",
                "returned_count": String(fetched.count),
                "retry": String(retryNumber),
                "profile_present": profilePresent ? "yes" : "no",
            ])
            ProductAnalytics.track("taxonomy_returned_count", properties: [
                "returned_count": String(fetched.count),
            ])
        } catch {
            guard generation == taxonomyLoadGeneration else { return }
            let status = (error as? APIError).flatMap { err -> Int? in
                if case .server(let code) = err { return code }
                return nil
            } ?? 0

            if let cached = taxonomy ?? loadCachedTaxonomy() {
                taxonomy = cached
                usingCachedCatalog = true
                catalogPhase = .offlineCached
                ProductAnalytics.track("taxonomy_load_failed", properties: [
                    "endpoint": "symptoms_taxonomy",
                    "http_status": String(status),
                    "safe_error": "network_using_cache",
                    "retry": String(retryNumber),
                    "profile_present": profilePresent ? "yes" : "no",
                ])
            } else {
                catalogPhase = .failed
                ProductAnalytics.track("taxonomy_load_failed", properties: [
                    "endpoint": "symptoms_taxonomy",
                    "http_status": String(status),
                    "safe_error": "decode_or_network",
                    "retry": String(retryNumber),
                    "profile_present": profilePresent ? "yes" : "no",
                ])
            }
        }
    }

    func loadHistory(profileId: String, userId: String, accessToken: String) async {
        guard !profileId.isEmpty else { return }
        ProductAnalytics.track("history_load_started", properties: [
            "endpoint": "symptoms_history",
            "profile_present": "yes",
        ])
        do {
            let response = try await apiClient.fetchSymptomHistory(
                profileId: profileId,
                userId: userId,
                accessToken: accessToken
            )
            history = response.items
            ProductAnalytics.track("history_load_succeeded", properties: [
                "endpoint": "symptoms_history",
                "returned_count": String(response.items.count),
                "profile_present": "yes",
            ])
        } catch {
            let status = (error as? APIError).flatMap { err -> Int? in
                if case .server(let code) = err { return code }
                return nil
            } ?? 0
            ProductAnalytics.track("history_load_failed", properties: [
                "endpoint": "symptoms_history",
                "http_status": String(status),
                "safe_error": "history_load",
                "profile_present": "yes",
            ])
        }
    }

    func setSearchText(_ value: String) {
        searchText = value
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self, !Task.isCancelled else { return }
            self.debouncedSearch = value
            self.objectWillChange.send()
        }
    }

    func clearSearch() {
        searchText = ""
        debouncedSearch = ""
    }

    func toggleFavorite(_ type: String) {
        if let index = favorites.firstIndex(of: type) {
            favorites.remove(at: index)
        } else {
            favorites.append(type)
        }
        persistFavorites()
    }

    func toggleCategory(_ id: String) {
        if expandedCategoryIDs.contains(id) {
            expandedCategoryIDs.remove(id)
        } else {
            expandedCategoryIDs.insert(id)
        }
    }

    func beginEntry(for type: String) {
        selectedType = type
        editingEntryId = nil
        if isRedFlag(type) {
            safetyNotice = taxonomy?.safetyNotice
        } else {
            safetyNotice = nil
        }
        showEntrySheet = true
    }

    func beginEdit(_ item: SymptomHistoryItem) {
        editingEntryId = item.id
        selectedType = item.symptomType
        severity = item.intensity
        note = item.note ?? ""
        showAdvancedFields = true
        showEntrySheet = true
    }

    func repeatEntry(_ item: SymptomHistoryItem) {
        editingEntryId = nil
        selectedType = item.symptomType
        severity = item.intensity
        onsetDate = Date()
        note = item.note ?? ""
        showAdvancedFields = false
        showEntrySheet = true
        ProductAnalytics.track("symptom_repeat_tapped")
    }

    var filteredCategories: [SymptomCategoryDTO] {
        guard let taxonomy else { return [] }
        let query = Self.fold(debouncedSearch.isEmpty ? searchText : debouncedSearch)
        return taxonomy.categories.compactMap { category in
            let symptoms = category.symptoms.filter { item in
                guard !query.isEmpty else { return true }
                let labelMatch = Self.fold(item.label).contains(query)
                let categoryMatch = Self.fold(category.label).contains(query)
                return labelMatch || categoryMatch
            }
            guard !symptoms.isEmpty else { return nil }
            return SymptomCategoryDTO(id: category.id, label: category.label, symptoms: symptoms)
        }
    }

    var favoriteItems: [SymptomTaxonomyItemDTO] {
        favorites.compactMap { type in labelItem(for: type) }
    }

    var recentItems: [SymptomTaxonomyItemDTO] {
        recents.compactMap { type in labelItem(for: type) }
    }

    func labelItem(for type: String) -> SymptomTaxonomyItemDTO? {
        for category in taxonomy?.categories ?? [] {
            if let item = category.symptoms.first(where: { $0.symptomType == type }) {
                return item
            }
        }
        return nil
    }

    func labelFor(_ type: String, fallback: String) -> String {
        labelItem(for: type)?.label ?? fallback
    }

    func isRedFlag(_ type: String) -> Bool {
        labelItem(for: type)?.redFlag == true
    }

    func groupedHistory(unknownLabel: String) -> [(title: String, items: [SymptomHistoryItem])] {
        let calendar = Calendar.current
        var today: [SymptomHistoryItem] = []
        var yesterday: [SymptomHistoryItem] = []
        var byDay: [Date: [SymptomHistoryItem]] = [:]

        for item in history {
            guard let date = Self.parseISODate(item.loggedAt) else { continue }
            if calendar.isDateInToday(date) {
                today.append(item)
            } else if calendar.isDateInYesterday(date) {
                yesterday.append(item)
            } else {
                let day = calendar.startOfDay(for: date)
                byDay[day, default: []].append(item)
            }
        }

        var sections: [(String, [SymptomHistoryItem])] = []
        if !today.isEmpty { sections.append(("today", today)) }
        if !yesterday.isEmpty { sections.append(("yesterday", yesterday)) }
        for day in byDay.keys.sorted(by: >) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            sections.append((formatter.string(from: day), byDay[day] ?? []))
        }
        return sections.map { (title: $0.0 == "today" || $0.0 == "yesterday" ? $0.0 : $0.0, items: $0.1) }
    }

    func submit(
        profileId: String,
        userId: String,
        accessToken: String,
        language: String
    ) async {
        guard let selectedType else {
            statusText = HiAirL10n.t("symptoms.select_first", lang: language)
            return
        }
        guard !loading else { return }
        loading = true
        defer { loading = false }

        if activeIdempotencyKey == nil {
            activeIdempotencyKey = UUID().uuidString
        }
        let idempotencyKey = activeIdempotencyKey!

        ProductAnalytics.track("symptom_save_started", properties: [
            "endpoint": editingEntryId == nil ? "symptoms_create" : "symptoms_patch",
            "profile_present": profileId.isEmpty ? "no" : "yes",
        ])

        do {
            if let editingEntryId {
                _ = try await apiClient.patchComprehensiveSymptom(
                    entryId: editingEntryId,
                    profileId: profileId,
                    severity: severity,
                    note: note.isEmpty ? nil : note,
                    durationMinutes: durationMinutes > 0 ? durationMinutes : nil,
                    ongoing: ongoing,
                    userId: userId,
                    accessToken: accessToken
                )
                statusText = HiAirL10n.t("symptoms.quick_saved", lang: language)
                ProductAnalytics.track("symptom_save_succeeded", properties: [
                    "endpoint": "symptoms_patch",
                    "profile_present": "yes",
                ])
            } else {
                let isoOnset = ISO8601DateFormatter().string(from: onsetDate)
                let result = try await apiClient.createComprehensiveSymptom(
                    ComprehensiveSymptomPayload(
                        profileId: profileId,
                        symptomType: selectedType,
                        severity: severity,
                        onsetAt: isoOnset,
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
                        customLabel: selectedType.hasPrefix("custom:") ? customLabel : nil,
                        clientRequestId: idempotencyKey
                    ),
                    userId: userId,
                    accessToken: accessToken,
                    language: language,
                    idempotencyKey: idempotencyKey
                )
                statusText = HiAirL10n.t("symptoms.quick_saved", lang: language)
                safetyNotice = result.safetyNotice
                pushRecent(selectedType)
                ProductAnalytics.track("symptom_save_succeeded", properties: [
                    "endpoint": "symptoms_create",
                    "profile_present": "yes",
                ])
                ProductAnalytics.track("symptom_logged", properties: ["mode": "comprehensive"])
            }

            clearDraftFieldsKeepingSelection(false)
            showEntrySheet = false
            pendingOfflineSave = false
            clearOfflineDraft()
            activeIdempotencyKey = nil
            await loadHistory(profileId: profileId, userId: userId, accessToken: accessToken)
        } catch {
            persistOfflineDraft(
                profileId: profileId,
                symptomType: selectedType,
                idempotencyKey: idempotencyKey
            )
            pendingOfflineSave = true
            statusText = HiAirL10n.t("symptoms.save_failed", lang: language)
            let status = (error as? APIError).flatMap { err -> Int? in
                if case .server(let code) = err { return code }
                return nil
            } ?? 0
            ProductAnalytics.track("symptom_save_failed", properties: [
                "endpoint": editingEntryId == nil ? "symptoms_create" : "symptoms_patch",
                "http_status": String(status),
                "safe_error": "save_failed",
                "profile_present": profileId.isEmpty ? "no" : "yes",
            ])
        }
    }

    func deleteEntry(
        _ item: SymptomHistoryItem,
        profileId: String,
        userId: String,
        accessToken: String,
        language: String
    ) async {
        do {
            try await apiClient.deleteComprehensiveSymptom(
                entryId: item.id,
                profileId: profileId,
                userId: userId,
                accessToken: accessToken
            )
            history.removeAll { $0.id == item.id }
            statusText = HiAirL10n.t("symptoms.deleted", lang: language)
        } catch {
            // Idempotent delete: treat 404 as success.
            if case .server(let code) = error as? APIError, code == 404 {
                history.removeAll { $0.id == item.id }
                return
            }
            statusText = HiAirL10n.t("symptoms.save_failed", lang: language)
        }
    }

    func flushOfflineDraftIfNeeded(
        profileId: String,
        userId: String,
        accessToken: String,
        language: String
    ) async {
        guard let draft = loadOfflineDraft() else { return }
        guard draft.profileId == profileId else { return }
        selectedType = draft.symptomType
        severity = draft.severity
        ongoing = draft.ongoing
        note = draft.note
        frequency = draft.frequency
        durationMinutes = draft.durationMinutes
        locationContext = draft.locationContext
        activityAtOnset = draft.activityAtOnset
        hydrationState = draft.hydrationState
        medicationTaken = draft.medicationTaken
        suspectedTrigger = draft.suspectedTrigger
        activeIdempotencyKey = draft.idempotencyKey
        await submit(
            profileId: profileId,
            userId: userId,
            accessToken: accessToken,
            language: language
        )
    }

    func createCustomSymptom(
        profileId: String,
        userId: String,
        accessToken: String,
        language: String
    ) async {
        let label = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        do {
            let created = try await apiClient.createCustomSymptom(
                profileId: profileId,
                label: label,
                userId: userId,
                accessToken: accessToken
            )
            customLabel = ""
            showCustomSheet = false
            beginEntry(for: created.symptomType)
            statusText = HiAirL10n.t("symptoms.custom_added", lang: language)
        } catch {
            statusText = HiAirL10n.t("symptoms.save_failed", lang: language)
        }
    }

    // MARK: - Persistence helpers

    private func syncFavoritesWithCatalog() {
        let available = Set((taxonomy?.categories ?? []).flatMap(\.symptoms).map(\.symptomType))
        if favorites.isEmpty {
            favorites = defaultFavoriteTypes.filter { available.contains($0) }
        } else {
            favorites = favorites.filter { available.contains($0) }
        }
        persistFavorites()
        recents = recents.filter { available.contains($0) }
        UserDefaults.standard.set(recents, forKey: recentsKey)
    }

    private func persistFavorites() {
        UserDefaults.standard.set(favorites, forKey: favoritesKey)
    }

    private func pushRecent(_ type: String) {
        recents.removeAll { $0 == type }
        recents.insert(type, at: 0)
        if recents.count > 8 {
            recents = Array(recents.prefix(8))
        }
        UserDefaults.standard.set(recents, forKey: recentsKey)
    }

    private func persistTaxonomyCache(_ value: SymptomTaxonomyDTO) {
        do {
            let envelope = TaxonomyCacheEnvelope(
                schemaVersion: taxonomySchemaVersion,
                loadedAt: Date().timeIntervalSince1970,
                taxonomy: value
            )
            let data = try JSONEncoder().encode(envelope)
            UserDefaults.standard.set(data, forKey: taxonomyCacheKey)
        } catch {
            // Cache is best-effort.
        }
    }

    private func loadCachedTaxonomy() -> SymptomTaxonomyDTO? {
        guard let data = UserDefaults.standard.data(forKey: taxonomyCacheKey) else { return nil }
        guard let envelope = try? JSONDecoder().decode(TaxonomyCacheEnvelope.self, from: data) else { return nil }
        guard envelope.schemaVersion == taxonomySchemaVersion else { return nil }
        guard envelope.taxonomy.categories.reduce(0, { $0 + $1.symptoms.count }) > 0 else { return nil }
        return envelope.taxonomy
    }

    private func clearDraftFieldsKeepingSelection(_ keep: Bool) {
        if !keep {
            selectedType = nil
            editingEntryId = nil
        }
        note = ""
        suspectedTrigger = ""
        durationMinutes = 0
        ongoing = false
        frequency = "unspecified"
        locationContext = "unspecified"
        activityAtOnset = "unspecified"
        hydrationState = "unspecified"
        medicationTaken = false
        onsetDate = Date()
        showAdvancedFields = false
    }

    private struct OfflineDraft: Codable {
        let profileId: String
        let symptomType: String
        let severity: Int
        let ongoing: Bool
        let note: String
        let frequency: String
        let durationMinutes: Int
        let locationContext: String
        let activityAtOnset: String
        let hydrationState: String
        let medicationTaken: Bool
        let suspectedTrigger: String
        let idempotencyKey: String
    }

    private struct TaxonomyCacheEnvelope: Codable {
        let schemaVersion: Int
        let loadedAt: TimeInterval
        let taxonomy: SymptomTaxonomyDTO
    }

    private func persistOfflineDraft(profileId: String, symptomType: String, idempotencyKey: String) {
        let draft = OfflineDraft(
            profileId: profileId,
            symptomType: symptomType,
            severity: severity,
            ongoing: ongoing,
            note: note,
            frequency: frequency,
            durationMinutes: durationMinutes,
            locationContext: locationContext,
            activityAtOnset: activityAtOnset,
            hydrationState: hydrationState,
            medicationTaken: medicationTaken,
            suspectedTrigger: suspectedTrigger,
            idempotencyKey: idempotencyKey
        )
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: offlineDraftKey)
        }
    }

    private func loadOfflineDraft() -> OfflineDraft? {
        guard let data = UserDefaults.standard.data(forKey: offlineDraftKey) else { return nil }
        return try? JSONDecoder().decode(OfflineDraft.self, from: data)
    }

    private func clearOfflineDraft() {
        UserDefaults.standard.removeObject(forKey: offlineDraftKey)
    }

    private static func fold(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private static func parseISODate(_ value: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    static func displayTime(for iso: String) -> String {
        guard let date = parseISODate(iso) else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SymptomLogView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = SymptomLogViewModel()
    @StateObject private var healthService = HealthKitService.shared
    @State private var entryPendingDelete: SymptomHistoryItem?
    @State private var healthSummary: HealthSummaryResponseDTO?
    @State private var wearableToday: WearableTodayResponse?
    @State private var showAllHealthMetrics = false
    private let apiClient = APIClient.live()

    var body: some View {
        HiAirAdaptiveLayout { width, mode in
            ScrollView {
                VStack(alignment: .leading, spacing: HiAirResponsiveSpacing.sectionSpacing(for: mode)) {
                    header
                    healthChrome
                    catalogStateBlock
                    if viewModel.taxonomy != nil {
                        searchBlock
                        quickAccessBlock
                        categoriesBlock
                        historyBlock
                    }
                    if !viewModel.statusText.isEmpty {
                        Text(viewModel.statusText)
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                            .accessibilityLabel(viewModel.statusText)
                    }
                }
                .hiAirContentWidth(for: width)
                .hiAirScreenPadding(for: width)
                .hiAirMainTabScrollContent()
            }
            .refreshable {
                await reloadAll(forceNetwork: true)
            }
        }
        .hiAirPageBackground()
        .onAppear {
            viewModel.onScreenOpened()
        }
        .task(id: session.preferredLanguage) {
            await reloadAll(forceNetwork: false)
        }
        .sheet(isPresented: $viewModel.showEntrySheet) {
            entrySheet
        }
        .sheet(isPresented: $viewModel.showCustomSheet) {
            customSheet
        }
        .confirmationDialog(
            session.l("symptoms.delete_confirm"),
            isPresented: Binding(
                get: { entryPendingDelete != nil },
                set: { if !$0 { entryPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(session.l("symptoms.delete"), role: .destructive) {
                guard let item = entryPendingDelete else { return }
                Task {
                    await viewModel.deleteEntry(
                        item,
                        profileId: session.profileId,
                        userId: session.userId,
                        accessToken: session.accessToken,
                        language: session.preferredLanguage
                    )
                }
            }
            Button(session.l("common.cancel"), role: .cancel) {
                entryPendingDelete = nil
            }
        }
    }

    private func dg(_ key: String) -> String {
        HiAirDeepGlassCopy.t(key, lang: session.preferredLanguage)
    }

    private var healthSuffix: String {
        let title = dg("health.title")
        if title.hasPrefix("HiAir ") {
            return String(title.dropFirst(6))
        }
        return session.l("tab.symptoms")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HiAirScreenWordmark(suffix: healthSuffix, suffixUsesGradient: true)
                Button {
                    session.selectedTab = 4
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(HiAirColors.Spectrum.cyan)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(HiAirColors.Spectrum.cyan.opacity(0.8), lineWidth: 1.2)
                        )
                        .shadow(color: HiAirColors.Spectrum.cyan.opacity(0.35), radius: 6)
                }
                .accessibilityLabel(session.l("tab.settings"))
            }
            Text(dg("checkin"))
                .font(HiAirTypography.displayLG)
                .foregroundStyle(HiAirColors.Text.primary)
                .accessibilityAddTraits(.isHeader)
            Text(dg("how_feeling"))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.secondary)
                .fixedLineSpacing(4)
            if viewModel.usingCachedCatalog {
                Text(session.l("symptoms.cached_offline"))
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirColors.Text.tertiary)
            }
        }
    }

    @ViewBuilder
    private var healthChrome: some View {
        if let load = wearableToday?.personalLoad {
            HiAirRecoveryHero(
                percent: min(max(load.score, 0), 100),
                title: recoveryTitle(load.level),
                bodyText: {
                    let text = load.explanations.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return text.isEmpty ? session.l("health.today.empty") : text
                }(),
                lang: session.preferredLanguage
            )
        }

        if !dailyMetricTiles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(dg("daily_metrics"))
                        .font(HiAirTypography.titleMD)
                        .foregroundStyle(HiAirColors.Text.primary)
                    Spacer()
                    Button(dg("view_all")) {
                        showAllHealthMetrics.toggle()
                    }
                    .font(HiAirTypography.caption.weight(.semibold))
                    .foregroundStyle(HiAirColors.Spectrum.cyan)
                }
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(dailyMetricTiles, id: \.title) { tile in
                        HiAirSparkMetricCard(
                            title: tile.title,
                            value: tile.value,
                            accent: tile.accent,
                            icon: tile.icon
                        )
                    }
                }
                if showAllHealthMetrics {
                    HealthTodayMetricsView(
                        summary: healthSummary,
                        personalLoad: wearableToday?.personalLoad
                    )
                }
            }
        }

        if !checkinChips.isEmpty {
            HStack {
                Text(dg("symptom_checkin"))
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirColors.Text.primary)
                Spacer()
                Image(systemName: "info.circle")
                    .foregroundStyle(HiAirColors.Text.secondary)
            }
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                ForEach(checkinChips) { item in
                    HiAirSymptomGlassChip(
                        title: item.label,
                        icon: symptomIcon(item.symptomType),
                        selected: viewModel.selectedType == item.symptomType
                    ) {
                        viewModel.beginEntry(for: item.symptomType)
                    }
                }
            }
        }

        HiAirIntensitySelector(value: $viewModel.severity, lang: session.preferredLanguage)

        Button(session.l("symptoms.add_custom")) {
            viewModel.showCustomSheet = true
        }
        .buttonStyle(HiAirOutlineCTAButtonStyle())
        .frame(minHeight: 44)
        .accessibilityIdentifier(HiAirAccessibilityID.Symptoms.addCustom)

        if let insight = wearableToday?.personalLoad?.explanations.first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !insight.isEmpty {
            HiAirSmartInsightCard(bodyText: insight, lang: session.preferredLanguage)
        } else if let notice = viewModel.taxonomy?.safetyNotice, !notice.isEmpty {
            HiAirSmartInsightCard(bodyText: notice, lang: session.preferredLanguage)
        }
    }

    private func recoveryTitle(_ level: String) -> String {
        switch level.lowercased() {
        case "low": return dg("good")
        case "moderate", "medium": return dg("spectrum.moderate")
        default: return dg("spectrum.high")
        }
    }

    private var checkinChips: [SymptomTaxonomyItemDTO] {
        Array((viewModel.taxonomy?.categories ?? []).flatMap(\.symptoms).prefix(6))
    }

    private var dailyMetricTiles: [(title: String, value: String, accent: Color, icon: String)] {
        var tiles: [(title: String, value: String, accent: Color, icon: String)] = []
        var byType: [String: HealthSummaryMetricDTO] = [:]
        for metric in healthSummary?.metrics ?? [] {
            if metric.displayValue != nil {
                byType[metric.metricType] = metric
            }
        }
        if let hr = byType["heart_rate"]?.displayValue ?? byType["resting_heart_rate"]?.displayValue {
            tiles.append((dg("heart"), "\(Int(hr.rounded())) bpm", HiAirColors.Risk.veryHigh, "heart.fill"))
        }
        if let steps = byType["steps"]?.displayValue {
            tiles.append((dg("steps"), "\(Int(steps.rounded()))", HiAirColors.Spectrum.cyan, "figure.walk"))
        }
        if let kcal = byType["active_energy"]?.displayValue {
            tiles.append((dg("kcal"), "\(Int(kcal.rounded())) kcal", HiAirColors.Risk.high, "flame.fill"))
        }
        if let sleepMin = healthSummary?.sleep?.totalMinutes {
            let hours = sleepMin / 60
            let mins = sleepMin % 60
            tiles.append((dg("sleep"), "\(hours)h \(mins)m", HiAirColors.Spectrum.violet, "moon.fill"))
        }
        return Array(tiles.prefix(4))
    }

    private func symptomIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "shortness_of_breath", "wheeze", "dyspnea", "breathing":
            return "lungs.fill"
        case "dizziness", "vertigo", "headache", "migraine":
            return "waveform.path.ecg"
        case "fatigue", "tiredness":
            return "zzz"
        case "cough":
            return "wind"
        case "itchy_eyes", "allergy", "allergic_rhinitis", "sneezing":
            return "allergens"
        default:
            return "circle.lefthalf.filled"
        }
    }

    @ViewBuilder
    private var catalogStateBlock: some View {
        switch viewModel.catalogPhase {
        case .idle, .loading:
            VStack(alignment: .leading, spacing: 12) {
                Text(session.l("symptoms.loading"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(HiAirColors.Overlay.subtle)
                        .frame(height: 56)
                        .redacted(reason: .placeholder)
                }
            }
            .v2Card()
        case .failed:
            VStack(alignment: .leading, spacing: 12) {
                Text(session.l("symptoms.taxonomy_failed"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                HStack(spacing: 10) {
                    Button(session.l("common.retry")) {
                        Task { await reloadAll(forceNetwork: true) }
                    }
                    .buttonStyle(HiAirGradientButtonStyle())
                    .frame(minHeight: 44)
                    Button(session.l("symptoms.check_connection")) {
                        Task { await reloadAll(forceNetwork: true) }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    .frame(minHeight: 44)
                }
            }
            .v2Card()
        case .loaded, .offlineCached:
            EmptyView()
        }
    }

    private var searchBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(session.l("symptoms.search"), text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.setSearchText($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(session.l("symptoms.search"))
                if !viewModel.searchText.isEmpty {
                    Button(session.l("symptoms.clear_search")) {
                        viewModel.clearSearch()
                    }
                    .font(AuroraTokens.Typography.caption.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            if !viewModel.searchText.isEmpty && viewModel.filteredCategories.isEmpty {
                Text(session.l("symptoms.no_search_results"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
            }
        }
        .v2Card()
    }

    @ViewBuilder
    private var quickAccessBlock: some View {
        if !viewModel.recentItems.isEmpty || !viewModel.favoriteItems.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                if !viewModel.recentItems.isEmpty {
                    Text(session.l("symptoms.recents"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    symptomChipRow(items: viewModel.recentItems)
                }
                if !viewModel.favoriteItems.isEmpty {
                    Text(session.l("symptoms.favorites"))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    symptomChipRow(items: viewModel.favoriteItems)
                }
            }
            .v2Card()
        }
    }

    private var categoriesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l("symptoms.categories"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)

            ForEach(viewModel.filteredCategories) { category in
                let expanded = viewModel.expandedCategoryIDs.contains(category.id) || !viewModel.searchText.isEmpty
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        viewModel.toggleCategory(category.id)
                    } label: {
                        HStack {
                            Text(category.label)
                                .font(AuroraTokens.Typography.bodyMD.weight(.semibold))
                                .foregroundStyle(HiAirV2Theme.primaryText)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Text("\(category.symptoms.count)")
                                .font(AuroraTokens.Typography.caption)
                                .foregroundStyle(HiAirV2Theme.tertiaryText)
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel(category.label)
                    .accessibilityHint(expanded ? "Collapse" : "Expand")

                    if expanded {
                        ForEach(category.symptoms) { item in
                            symptomRow(item)
                        }
                    }
                }
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) {
                    Divider().opacity(0.35)
                }
            }
        }
        .v2Card()
    }

    private var historyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.l("symptoms.history"))
                .font(AuroraTokens.Typography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)

            if viewModel.history.isEmpty {
                Text(session.l("symptoms.history_empty"))
                    .font(AuroraTokens.Typography.bodyMD)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
            } else {
                let sections = viewModel.groupedHistory(unknownLabel: session.l("symptoms.unknown"))
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    Text(historySectionTitle(section.title))
                        .font(AuroraTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(HiAirV2Theme.tertiaryText)
                        .padding(.top, 4)
                    ForEach(section.items, id: \.id) { item in
                        historyRow(item)
                    }
                }
            }
        }
        .v2Card()
    }

    private func symptomChipRow(items: [SymptomTaxonomyItemDTO]) -> some View {
        FlowWrap(items: items) { item in
            HiAirSymptomGlassChip(
                title: item.label,
                icon: symptomIcon(item.symptomType),
                selected: viewModel.selectedType == item.symptomType
            ) {
                viewModel.beginEntry(for: item.symptomType)
            }
        }
    }

    private func symptomRow(_ item: SymptomTaxonomyItemDTO) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                viewModel.beginEntry(for: item.symptomType)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: item.redFlag ? "exclamationmark.triangle.fill" : "circle.fill")
                        .font(.caption)
                        .foregroundStyle(item.redFlag ? AuroraTokens.ColorPalette.errorSoft : HiAirV2Theme.tertiaryText)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if item.redFlag {
                            Text(session.l("symptoms.red_flag_hint"))
                                .font(AuroraTokens.Typography.caption)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                viewModel.toggleFavorite(item.symptomType)
            } label: {
                Image(systemName: viewModel.favorites.contains(item.symptomType) ? "star.fill" : "star")
                    .foregroundStyle(HiAirV2Theme.secondaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(session.l("symptoms.favorites"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(HiAirColors.Overlay.subtle, in: RoundedRectangle(cornerRadius: 12))
    }

    private func historyRow(_ item: SymptomHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(viewModel.labelFor(item.symptomType, fallback: session.l("symptoms.unknown")))
                    .font(AuroraTokens.Typography.bodyMD.weight(.semibold))
                    .foregroundStyle(HiAirV2Theme.primaryText)
                Spacer()
                Text(SymptomLogViewModel.displayTime(for: item.loggedAt))
                    .font(AuroraTokens.Typography.caption)
                    .foregroundStyle(HiAirV2Theme.tertiaryText)
            }
            Text("\(session.l("symptoms.severity")): \(item.intensity)")
                .font(AuroraTokens.Typography.caption)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            HStack(spacing: 12) {
                Button(session.l("symptoms.repeat")) {
                    viewModel.repeatEntry(item)
                }
                .frame(minHeight: 44)
                Button(session.l("symptoms.edit")) {
                    viewModel.beginEdit(item)
                }
                .frame(minHeight: 44)
                Button(session.l("symptoms.delete"), role: .destructive) {
                    entryPendingDelete = item
                }
                .frame(minHeight: 44)
            }
        }
        .padding(10)
        .background(HiAirColors.Overlay.subtle, in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button(session.l("symptoms.repeat")) {
                viewModel.repeatEntry(item)
            }
            Button(session.l("symptoms.edit")) {
                viewModel.beginEdit(item)
            }
            Button(session.l("symptoms.delete"), role: .destructive) {
                entryPendingDelete = item
            }
        }
    }

    private var entrySheet: some View {
        NavigationStack {
            Form {
                if let type = viewModel.selectedType {
                    Section {
                        Text(viewModel.labelFor(type, fallback: session.l("symptoms.unknown")))
                            .font(AuroraTokens.Typography.titleMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                        if viewModel.isRedFlag(type), let notice = viewModel.taxonomy?.safetyNotice {
                            Text(notice)
                                .font(AuroraTokens.Typography.caption)
                                .foregroundStyle(AuroraTokens.ColorPalette.errorSoft)
                        }
                    }

                    Section(session.l("symptoms.severity")) {
                        Text(severityCaption(viewModel.severity))
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                        Picker(session.l("symptoms.severity"), selection: $viewModel.severity) {
                            ForEach(1...5, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section {
                        DatePicker(
                            session.l("symptoms.onset"),
                            selection: $viewModel.onsetDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        Toggle(session.l("symptoms.ongoing"), isOn: $viewModel.ongoing)
                    }

                    Section {
                        Toggle(session.l("symptoms.more_details"), isOn: $viewModel.showAdvancedFields)
                        if viewModel.showAdvancedFields {
                            Picker(session.l("symptoms.location"), selection: $viewModel.locationContext) {
                                Text(session.l("symptoms.location.any")).tag("unspecified")
                                Text(session.l("symptoms.location.indoors")).tag("indoors")
                                Text(session.l("symptoms.location.outdoors")).tag("outdoors")
                            }
                            Picker(session.l("symptoms.frequency"), selection: $viewModel.frequency) {
                                Text(session.l("symptoms.frequency.any")).tag("unspecified")
                                Text(session.l("symptoms.frequency.once")).tag("once")
                                Text(session.l("symptoms.frequency.intermittent")).tag("intermittent")
                                Text(session.l("symptoms.frequency.constant")).tag("constant")
                            }
                            Picker(session.l("symptoms.duration"), selection: $viewModel.durationMinutes) {
                                Text(session.l("symptoms.duration.any")).tag(0)
                                Text(session.l("symptoms.duration.15m")).tag(15)
                                Text(session.l("symptoms.duration.1h")).tag(60)
                                Text(session.l("symptoms.duration.3h")).tag(180)
                                Text(session.l("symptoms.duration.day")).tag(1440)
                            }
                            Picker(session.l("symptoms.activity"), selection: $viewModel.activityAtOnset) {
                                Text(session.l("symptoms.activity.any")).tag("unspecified")
                                Text(session.l("symptoms.activity.rest")).tag("rest")
                                Text(session.l("symptoms.activity.walk")).tag("walk")
                                Text(session.l("symptoms.activity.exercise")).tag("exercise")
                                Text(session.l("symptoms.activity.work")).tag("work")
                                Text(session.l("symptoms.activity.sleep")).tag("sleep")
                            }
                            Picker(session.l("symptoms.hydration"), selection: $viewModel.hydrationState) {
                                Text(session.l("symptoms.hydration.any")).tag("unspecified")
                                Text(session.l("symptoms.hydration.low")).tag("low")
                                Text(session.l("symptoms.hydration.ok")).tag("adequate")
                                Text(session.l("symptoms.hydration.high")).tag("high")
                            }
                            Toggle(session.l("symptoms.medication"), isOn: $viewModel.medicationTaken)
                            TextField(session.l("symptoms.trigger_optional"), text: $viewModel.suspectedTrigger)
                            TextField(session.l("symptoms.note_optional"), text: $viewModel.note, axis: .vertical)
                                .lineLimit(2...4)
                        }
                    }
                }
            }
            .navigationTitle(session.l("symptoms.entry_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(session.l("common.cancel")) {
                        viewModel.showEntrySheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
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
                    .disabled(viewModel.loading || session.profileId.isEmpty || viewModel.selectedType == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var customSheet: some View {
        NavigationStack {
            Form {
                TextField(session.l("symptoms.custom_label"), text: $viewModel.customLabel)
            }
            .navigationTitle(session.l("symptoms.add_custom"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(session.l("common.cancel")) { viewModel.showCustomSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(session.l("symptoms.save")) {
                        Task {
                            await viewModel.createCustomSymptom(
                                profileId: session.profileId,
                                userId: session.userId,
                                accessToken: session.accessToken,
                                language: session.preferredLanguage
                            )
                        }
                    }
                    .disabled(viewModel.customLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func reloadAll(forceNetwork: Bool) async {
        _ = await session.ensureProfileIdIfNeeded()
        await viewModel.loadTaxonomy(
            language: session.preferredLanguage,
            profilePresent: !session.profileId.isEmpty,
            forceNetwork: forceNetwork
        )
        if !session.profileId.isEmpty {
            await viewModel.loadHistory(
                profileId: session.profileId,
                userId: session.userId,
                accessToken: session.accessToken
            )
            await viewModel.flushOfflineDraftIfNeeded(
                profileId: session.profileId,
                userId: session.userId,
                accessToken: session.accessToken,
                language: session.preferredLanguage
            )
        }
        await loadHealthChrome()
    }

    private func loadHealthChrome() async {
        guard !session.userId.isEmpty, !session.accessToken.isEmpty else { return }
        if !UITestBootstrap.isStoreShots {
            switch healthService.connectionState {
            case .connected, .systemAuthorized:
                break
            default:
                return
            }
        }
        async let todayTask = apiClient.fetchWearableToday(
            userId: session.userId,
            accessToken: session.accessToken
        )
        async let summaryTask = apiClient.fetchHealthSummary(
            userId: session.userId,
            accessToken: session.accessToken
        )
        wearableToday = try? await todayTask
        healthSummary = try? await summaryTask
    }

    private func historySectionTitle(_ key: String) -> String {
        switch key {
        case "today":
            return session.l("symptoms.today")
        case "yesterday":
            return session.l("symptoms.yesterday")
        default:
            return key
        }
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

private extension View {
    func fixedLineSpacing(_ spacing: CGFloat) -> some View {
        self.lineSpacing(spacing)
    }
}

/// Simple wrapping layout for symptom chips without LazyVGrid density issues.
private struct FlowWrap<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geometry in
            generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                content(item)
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height
                        }
                        let result = width
                        if item.id == items.last?.id {
                            width = 0
                        } else {
                            width -= dimension.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item.id == items.last?.id {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: FlowHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(FlowHeightKey.self) { totalHeight = $0 }
    }
}

private struct FlowHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
