import Foundation

/// Serialized (MainActor) ownership of the shared session Keychain + UserDefaults.
/// Writers compare their claimed generation before any mutation so a stale AppSession
/// cannot erase a newer account between a check and a write.
@MainActor
final class SessionDurableOwnership {
    static let shared = SessionDurableOwnership()

    private(set) var generation: UInt64 = 0
    private(set) var ownerUserId: String = ""

    @discardableResult
    func claim(userId: String) -> UInt64 {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        generation &+= 1
        ownerUserId = trimmed
        return generation
    }

    /// After an owning logout clears durable credentials, bump so stale writers cannot delete.
    func releaseAfterOwnedClear(expectedGeneration: UInt64) {
        guard expectedGeneration != 0, expectedGeneration == generation else { return }
        generation &+= 1
        ownerUserId = ""
    }

    func isCurrent(_ claimedGeneration: UInt64) -> Bool {
        claimedGeneration != 0 && claimedGeneration == generation
    }
}

@MainActor
final class AppSession: ObservableObject {
    private enum Keys {
        static let onboardingCompleted = "session.onboardingCompleted"
        static let checklistCompletedItems = "session.checklistCompletedItems"
        static let checklistHidden = "session.checklistHidden"
        static let userId = "session.userId"
        static let accessToken = "session.accessToken"
        static let refreshToken = "session.refreshToken"
        static let email = "session.email"
        static let profileId = "session.profileId"
        static let persona = "session.persona"
        static let sensitivity = "session.sensitivity"
        static let preferredLanguage = "session.preferredLanguage"
        static let latitude = "session.latitude"
        static let longitude = "session.longitude"
        static let locationSource = "session.locationSource"
        static let displayPlaceName = "session.displayPlaceName"
        static let dateOfBirth = "session.dateOfBirth"
    }

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    @Published var onboardingCompleted = false { didSet { persist() } }
    @Published var userId = "" { didSet { persist() } }
    @Published var email = "" { didSet { persist() } }
    @Published var accessToken = "" { didSet { persist() } }
    @Published var refreshToken = "" { didSet { persist() } }
    @Published var authNotice = ""
    @Published var profileId = "" { didSet { persist() } }
    @Published var persona = "adult" { didSet { persist() } }
    @Published var sensitivity = "medium" { didSet { persist() } }
    @Published var preferredLanguage = "ru" { didSet { persist() } }
    @Published var latitude = 0.0 { didSet { persist() } }
    @Published var longitude = 0.0 { didSet { persist() } }
    @Published var locationSource: LocationSource = .unknown { didSet { persist() } }
    @Published var locationRevision = 0
    /// Resolved locality (Barcelona / Castelldefels). Cached for instant cold-start chip.
    @Published var displayPlaceName: String? = nil { didSet { persist() } }
    @Published var isResolvingPlaceName = false
    @Published var dateOfBirth: Date? { didSet { persist() } }
    @Published var checklistCompletedItems: Set<String> = [] { didSet { persist() } }
    @Published var checklistHidden = false { didSet { persist() } }
    @Published var showOnboardingFromSettings = false
    @Published var showPaywall = false
    @Published var isPremium = false
    /// True after StoreKit verified until backend confirms or terminal rollback.
    @Published var premiumActivationPending = false
    @Published var selectedTab = 0
    /// True while list/create profile network work is in flight (single-flight).
    @Published private(set) var isEnsuringProfile = false
    /// Last non-transient outcome from `ensureProfileIdIfNeeded` for UI messaging.
    @Published private(set) var lastProfileEnsureOutcome: ProfileEnsureOutcome?
    /// Last ensure phase for telemetry / diagnostics (safe, non-PII).
    @Published private(set) var lastProfileEnsurePhase: ProfileEnsurePhase = .idle
    /// Generation stamp used to skip redundant ensure right after prepareSession.
    private(set) var lastProfileEnsureCompletedAt: Date?
    private let apiClient: APIClient
    private let defaults: UserDefaults
    private let credentials: any SessionCredentialStoring
    private let durableOwnership: SessionDurableOwnership
    /// Claimed generation for this instance; must match `durableOwnership.generation` to mutate store.
    private var durableOwnershipGeneration: UInt64 = 0
    private var isHydratingFromStore = false
    private let supabaseAuth = SupabaseAuthService.shared
    private let remoteSessionRevoker: any AuthRemoteSessionRevoking
    private var authObserver: NSObjectProtocol?
    private var locationAuthObserver: NSObjectProtocol?
    private var oauthFailedObserver: NSObjectProtocol?
    private var entitlementObserver: NSObjectProtocol?
    private var startupTask: Task<Void, Never>?
    private var inFlightPrepare: Task<SessionPrepareResult, Never>?
    private var inFlightEnsureProfile: Task<ProfileEnsureOutcome, Never>?
    /// Best-effort remote revoke of a captured access token (not cancelled on logout).
    private var signOutTask: Task<Void, Never>?
    /// Token currently being revoked remotely — dedupes concurrent logout for the same bearer.
    private var inFlightRemoteRevokeToken: String?
    private var placeInvalidateTask: Task<Void, Never>?
    private var lastForegroundRefreshAt: Date?
    /// Invalidates in-flight reverse-geocode applies after logout / newer coords.
    private var placeResolveGeneration: UInt64 = 0
    /// While true, skip APIClient mutation from `persist()` (logout memory clear).
    private var suppressAPIClientAuthSync = false
    /// Bumped whenever an in-flight profile ensure must be abandoned (logout/auth switch).
    private var profileEnsureGeneration: UInt64 = 0
    /// One data-fetch / foreground cycle may perform at most one underlying profile ensure attempt.
    private var profileEnsureCycleGeneration: UInt64 = 0
    private var profileEnsureCycleUserId: String = ""
    private var profileEnsureCycleTerminal: ProfileEnsureOutcome?
    /// Underlying ensure attempts in the active cycle (test seam + diagnostics).
    private(set) var profileEnsureCycleAttemptCount: Int = 0
    /// Location revisions observed while a prepare/ensure cycle is open (bootstrap must not open a new cycle).
    private var profileEnsureCycleLocationRevisions: Set<Int> = []
    private var prepareSessionNestingDepth: Int = 0

    /// Explicit Retry / new foreground activation — opens a fresh ensure cycle.
    func beginExplicitProfileEnsureCycle() {
        profileEnsureCycleGeneration &+= 1
        profileEnsureCycleUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        profileEnsureCycleTerminal = nil
        profileEnsureCycleAttemptCount = 0
        profileEnsureCycleLocationRevisions = []
        if locationRevision > 0 {
            profileEnsureCycleLocationRevisions.insert(locationRevision)
        }
    }

    private func openProfileEnsureCycleIfNeeded() {
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return }
        // Keep the active cycle for this user whether the ensure is in-flight or already terminal.
        // Downstream callers (sibling Tab `.task`, locationRevision reload) must join / reuse —
        // not open a fresh attempt after the first terminal result.
        if profileEnsureCycleUserId == uid, profileEnsureCycleGeneration > 0 {
            return
        }
        beginExplicitProfileEnsureCycle()
    }

    private func storeProfileEnsureCycleTerminal(_ outcome: ProfileEnsureOutcome) {
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return }
        if profileEnsureCycleGeneration == 0 || profileEnsureCycleUserId != uid {
            openProfileEnsureCycleIfNeeded()
        }
        profileEnsureCycleTerminal = outcome
        if locationRevision > 0 {
            profileEnsureCycleLocationRevisions.insert(locationRevision)
        }
    }

    private func memoizedProfileEnsureOutcomeForCurrentCycle() -> ProfileEnsureOutcome? {
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty,
              profileEnsureCycleUserId == uid,
              let terminal = profileEnsureCycleTerminal
        else {
            return nil
        }
        return terminal
    }

    private func cancelInFlightProfileEnsure(clearOutcome: Bool) {
        profileEnsureGeneration &+= 1
        inFlightEnsureProfile?.cancel()
        inFlightEnsureProfile = nil
        isEnsuringProfile = false
        profileEnsureCycleGeneration &+= 1
        profileEnsureCycleUserId = ""
        profileEnsureCycleTerminal = nil
        profileEnsureCycleAttemptCount = 0
        profileEnsureCycleLocationRevisions = []
        if clearOutcome {
            lastProfileEnsureOutcome = nil
        }
    }

    /// Abandon single-flight session prepare so a replacement account cannot coalesce onto it.
    private func cancelInFlightSessionPrepare() {
        inFlightPrepare?.cancel()
        inFlightPrepare = nil
    }

    private func isCurrentProfileEnsureContext(
        userId: String,
        accessToken: String,
        generation: UInt64
    ) -> Bool {
        guard !Task.isCancelled else { return false }
        guard generation == profileEnsureGeneration else { return false }
        // Same-user token rotation (401 refresh) must not abandon ensure.
        // Account switch bumps generation via cancelInFlightProfileEnsure.
        guard self.userId == userId else { return false }
        _ = accessToken // retained for call-site clarity / future audit
        return true
    }

    /// Prefer the live session bearer when still the same user (post-refresh).
    private func ensureAccessToken(
        requestedUserId: String,
        fallback: String
    ) -> String {
        if self.userId == requestedUserId, !accessToken.isEmpty {
            return accessToken
        }
        return fallback
    }

    /// Test seam: count of still-registered NotificationCenter observers.
    var testRegisteredObserverCountForTests: Int {
        [authObserver, locationAuthObserver, oauthFailedObserver, entitlementObserver]
            .compactMap { $0 }
            .count
    }

    /// Test seam: whether startup restore task is absent or cancelled.
    var testStartupTaskIsCancelledForTests: Bool {
        guard let startupTask else { return true }
        return startupTask.isCancelled
    }

    /// Test seam: await in-flight remote revoke started by `logout()`.
    func awaitRemoteRevokeForTests() async {
        await signOutTask?.value
    }

    /// Test seam: mirrors `deinit` cleanup without destroying the instance
    /// (so unit tests can assert observer/startup cancellation deterministically).
    /// Does **not** cancel an in-flight remote revoke — that must complete with the
    /// captured bearer even if the session object is torn down for observers.
    func cancelLifecycleForTests() {
        startupTask?.cancel()
        startupTask = nil
        inFlightPrepare?.cancel()
        inFlightPrepare = nil
        cancelInFlightProfileEnsure(clearOutcome: false)
        placeInvalidateTask?.cancel()
        placeInvalidateTask = nil
        lastForegroundRefreshAt = nil
        let observers = [authObserver, locationAuthObserver, oauthFailedObserver, entitlementObserver]
        authObserver = nil
        locationAuthObserver = nil
        oauthFailedObserver = nil
        entitlementObserver = nil
        for observer in observers {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    /// Localized message for the last profile-ensure failure/blocker, if any.
    var profileEnsureUserMessage: String? {
        guard let key = lastProfileEnsureOutcome?.messageKey else { return nil }
        return l(key)
    }

    init(
        remoteSessionRevoker: (any AuthRemoteSessionRevoking)? = nil,
        defaults: UserDefaults = .standard,
        credentials: (any SessionCredentialStoring)? = nil,
        durableOwnership: SessionDurableOwnership? = nil,
        apiClient: APIClient? = nil
    ) {
        self.remoteSessionRevoker = remoteSessionRevoker ?? SupabaseAuthService.shared
        self.defaults = defaults
        self.credentials = credentials ?? KeychainStore(service: "com.hiair.app.session")
        self.durableOwnership = durableOwnership ?? .shared
        self.apiClient = apiClient ?? APIClient.live()
        isHydratingFromStore = true
        onboardingCompleted = defaults.object(forKey: Keys.onboardingCompleted) as? Bool ?? false
        userId = self.credentials.getString(forKey: Keys.userId) ?? defaults.string(forKey: Keys.userId) ?? ""
        email = self.credentials.getString(forKey: Keys.email) ?? defaults.string(forKey: Keys.email) ?? ""
        accessToken = self.credentials.getString(forKey: Keys.accessToken) ?? defaults.string(forKey: Keys.accessToken) ?? ""
        refreshToken = self.credentials.getString(forKey: Keys.refreshToken) ?? defaults.string(forKey: Keys.refreshToken) ?? ""
        profileId = defaults.string(forKey: Keys.profileId) ?? ""
        persona = defaults.string(forKey: Keys.persona) ?? "adult"
        sensitivity = defaults.string(forKey: Keys.sensitivity) ?? "medium"
        preferredLanguage = defaults.string(forKey: Keys.preferredLanguage) ?? "ru"
        latitude = defaults.object(forKey: Keys.latitude) as? Double ?? 0.0
        longitude = defaults.object(forKey: Keys.longitude) as? Double ?? 0.0
        if let rawSource = defaults.string(forKey: Keys.locationSource),
           let parsed = LocationSource(rawValue: rawSource) {
            locationSource = parsed
        } else {
            locationSource = .unknown
        }
        // Do not restore a global city name — presentation is account-scoped via PlaceGeocodingService.
        displayPlaceName = nil
        if let birthRaw = defaults.string(forKey: Keys.dateOfBirth) {
            dateOfBirth = Self.birthDateFormatter.date(from: birthRaw)
        }
        checklistCompletedItems = Set(defaults.stringArray(forKey: Keys.checklistCompletedItems) ?? [])
        checklistHidden = defaults.object(forKey: Keys.checklistHidden) as? Bool ?? false
        isHydratingFromStore = false

        let hasUsableAuth = !userId.isEmpty && !accessToken.isEmpty
        if hasUsableAuth {
            durableOwnershipGeneration = self.durableOwnership.claim(userId: userId)
            // Drop legacy plaintext copies once credential store is the owner store.
            defaults.removeObject(forKey: Keys.displayPlaceName)
            writeDurableSessionFields()
            APIClient.setAuthState(
                APIClient.AuthState(
                    userId: userId,
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )
            )
        } else {
            // Empty hydrate must not wipe a newer in-memory APIClient account B.
            defaults.removeObject(forKey: Keys.displayPlaceName)
        }

        APIClient.setAuthInvalidatedHandler { [weak self] in
            Task { @MainActor in
                self?.expireSessionAfterAuthFailure()
            }
        }
        authObserver = NotificationCenter.default.addObserver(
            forName: SupabaseAuthService.sessionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let session = note.object as? SupabaseAuthSession
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let session else {
                    self.logout()
                    return
                }
                self.installAuthSession(session)
                await self.refreshEntitlement()
            }
        }
        oauthFailedObserver = NotificationCenter.default.addObserver(
            forName: SupabaseAuthService.sessionOAuthFailed,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let message = note.object as? String ?? ""
            Task { @MainActor [weak self] in
                guard let self, !message.isEmpty else { return }
                self.authNotice = message
            }
        }
        entitlementObserver = NotificationCenter.default.addObserver(
            forName: .subscriptionEntitlementDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let entitlement = note.object as? UserEntitlementResponse
            let pending = note.userInfo?["activationPending"] as? Bool ?? false
            let rollback = note.userInfo?["rollback"] as? Bool ?? false
            Task { @MainActor [weak self] in
                guard let self else { return }
                if rollback {
                    // Require account attribution so a delayed terminal rejection
                    // from a previous session cannot clear the signed-in account.
                    guard Self.shouldApplyRollbackNotification(
                        currentUserId: self.userId,
                        notedUserId: note.userInfo?["userId"] as? String
                    ) else { return }
                    self.rollbackPremiumActivation()
                    return
                }
                // Ignore stale entitlement notifications for a different account.
                if let entitlement, !entitlement.userId.isEmpty, entitlement.userId != self.userId {
                    return
                }
                if pending {
                    if let entitlement {
                        self.beginPremiumActivation(optimistic: entitlement)
                    }
                    return
                }
                self.confirmPremiumActivation(entitlement)
            }
        }
        locationAuthObserver = NotificationCenter.default.addObserver(
            forName: .locationAuthorizationDidBecomeAuthorized,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if UITestBootstrap.disableAutoProfileBootstrap {
                    return
                }
                StartupDiagnostics.track("location_bootstrap_started", errorCode: "auth_granted")
                _ = await self.bootstrapLocationFromDevice()
                _ = await self.ensureProfileIdIfNeeded()
            }
        }
        startupTask = Task { @MainActor [weak self] in
            if UITestBootstrap.isUITesting {
                return
            }
            StartupDiagnostics.track("startup_begin")
            await self?.restoreSupabaseSession()
            guard let self, !Task.isCancelled else { return }
            self.syncAPIClientAuthFromPersist()
            if !self.userId.isEmpty {
                HealthKitService.shared.bindAccount(userId: self.userId)
                await PlaceGeocodingService.shared.bindAccount(userId: self.userId)
                if let cached = await PlaceGeocodingService.shared.presentationPlaceName(for: self.userId) {
                    self.displayPlaceName = cached
                }
            }
            guard !Task.isCancelled else { return }
            await self.refreshEntitlement()
        }
    }

    deinit {
        // Match cancelLifecycleForTests for observers/startup — but do **not** cancel
        // an in-flight remote revoke; it must finish with the captured bearer.
        startupTask?.cancel()
        startupTask = nil
        inFlightPrepare?.cancel()
        inFlightPrepare = nil
        // deinit is nonisolated — cancel the task handle directly (no MainActor helper).
        inFlightEnsureProfile?.cancel()
        inFlightEnsureProfile = nil
        placeInvalidateTask?.cancel()
        placeInvalidateTask = nil
        let observers = [authObserver, locationAuthObserver, oauthFailedObserver, entitlementObserver]
        authObserver = nil
        locationAuthObserver = nil
        oauthFailedObserver = nil
        entitlementObserver = nil
        for observer in observers {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        // Do not clear APIClient.setAuthInvalidatedHandler here — a newer AppSession
        // may already own it; the handler captures [weak self] and no-ops after release.
    }

    func logout() {
        cancelInFlightSessionPrepare()
        cancelInFlightProfileEnsure(clearOutcome: true)

        // 1) Immutable account-correlated snapshot BEFORE any local clear.
        let snapshotUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshotLocalToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let ownershipGen = durableOwnershipGeneration
        let ownsDurable = durableOwnership.isCurrent(ownershipGen)
        let global = APIClient.getAuthState()
        let ownsGlobalAuth = !snapshotUserId.isEmpty && global?.userId == snapshotUserId
        let capturedAccessToken: String = {
            if ownsGlobalAuth,
               let globalToken = global?.accessToken.trimmingCharacters(in: .whitespacesAndNewlines),
               !globalToken.isEmpty {
                return globalToken
            }
            // Stale / mismatched global (account B) — never revoke B's bearer.
            return snapshotLocalToken
        }()

        // 2) Owning logout clears durable credentials under the claimed generation, then
        //    bumps ownership so late/stale writers cannot delete a newer account.
        //    Stale logout must not mutate shared Keychain/UserDefaults owned by B.
        if ownsDurable {
            clearDurableSessionStorage()
            durableOwnership.releaseAfterOwnedClear(expectedGeneration: ownershipGen)
        }
        durableOwnershipGeneration = 0

        // 3) Immediate in-memory cleanup for THIS session. Do not wipe foreign global B.
        placeResolveGeneration &+= 1
        isResolvingPlaceName = false
        isPremium = false
        premiumActivationPending = false
        if ownsGlobalAuth || HealthKitService.shared.boundUserId == snapshotUserId {
            HealthKitService.shared.clearAccountSession()
        }
        placeInvalidateTask?.cancel()
        if ownsGlobalAuth {
            placeInvalidateTask = Task {
                await PlaceGeocodingService.shared.invalidateSession()
            }
        }

        // Suppress durable + APIClient side effects while clearing published fields.
        // Ownership already released — persist() must not delete B's keychain/defaults.
        suppressAPIClientAuthSync = true
        isHydratingFromStore = true
        userId = ""
        email = ""
        accessToken = ""
        refreshToken = ""
        authNotice = ""
        profileId = ""
        selectedTab = 0
        latitude = 0.0
        longitude = 0.0
        locationSource = .unknown
        locationRevision = 0
        displayPlaceName = nil
        isHydratingFromStore = false
        suppressAPIClientAuthSync = false

        if ownsGlobalAuth {
            APIClient.setAuthState(nil)
        }

        // 4) No token ⇒ no network and no nil sessionDidChange rebroadcast.
        guard !capturedAccessToken.isEmpty else { return }

        // 5) Concurrent logout for the same bearer: keep the in-flight revoke (one request).
        if inFlightRemoteRevokeToken == capturedAccessToken {
            return
        }

        inFlightRemoteRevokeToken = capturedAccessToken
        let token = capturedAccessToken
        let revoker = remoteSessionRevoker
        signOutTask = Task { [weak self] in
            await revoker.revokeRemoteSession(accessToken: token)
            await MainActor.run {
                guard let self else { return }
                if self.inFlightRemoteRevokeToken == token {
                    self.inFlightRemoteRevokeToken = nil
                }
                // Never clear APIClient / durable store / Health from late revoke completion.
            }
        }
    }

    /// Clears city / Health / Premium presentation owned by the signed-in session.
    /// Does not revoke system HealthKit permission.
    func clearAccountPresentationState() {
        placeResolveGeneration &+= 1
        displayPlaceName = nil
        isResolvingPlaceName = false
        isPremium = false
        premiumActivationPending = false
        HealthKitService.shared.clearAccountSession()
        placeInvalidateTask?.cancel()
        placeInvalidateTask = Task {
            await PlaceGeocodingService.shared.invalidateSession()
        }
    }

    func markChecklistItem(_ id: String, done: Bool) {
        if done {
            checklistCompletedItems.insert(id)
        } else {
            checklistCompletedItems.remove(id)
        }
    }

    func isChecklistItemDone(_ id: String) -> Bool {
        checklistCompletedItems.contains(id)
    }

    func resetChecklist() {
        checklistCompletedItems = []
        checklistHidden = false
    }

    func finishOnboarding() {
        onboardingCompleted = true
        checklistHidden = false
        ProductAnalytics.track("onboarding_completed")
    }

    /// Apply Supabase tokens in one shot so `persist()` does not clear API auth mid-update.
    /// Claims durable-store ownership before writing so this account becomes the sole writer.
    func installAuthSession(_ auth: SupabaseAuthSession) {
        let previousUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextUserId = auth.userId.trimmingCharacters(in: .whitespacesAndNewlines)
        // Same-user token rotation must not cancel in-flight profile ensure / prepare.
        if previousUserId != nextUserId {
            cancelInFlightSessionPrepare()
            cancelInFlightProfileEnsure(clearOutcome: true)
        }
        durableOwnershipGeneration = durableOwnership.claim(userId: auth.userId)
        userId = auth.userId
        email = auth.email
        accessToken = auth.accessToken
        refreshToken = auth.refreshToken
        authNotice = ""
        // Never keep another account's profileId / location across auth install.
        if previousUserId != nextUserId {
            profileId = ""
            latitude = 0
            longitude = 0
            locationSource = .unknown
            displayPlaceName = nil
            locationRevision += 1
            lastProfileEnsureOutcome = nil
        }
        HealthKitService.shared.bindAccount(userId: auth.userId)
        Task {
            await PlaceGeocodingService.shared.bindAccount(userId: auth.userId)
            if let cached = await PlaceGeocodingService.shared.presentationPlaceName(for: auth.userId) {
                await MainActor.run {
                    guard self.userId == auth.userId else { return }
                    self.displayPlaceName = cached
                }
            }
        }
    }

    func applyEntitlement(_ entitlement: UserEntitlementResponse?, activationPending: Bool = false) {
        isPremium = entitlement?.isPremium ?? false
        if entitlement?.isPremium == true {
            premiumActivationPending = activationPending
        } else {
            premiumActivationPending = false
        }
    }

    func beginPremiumActivation(optimistic: UserEntitlementResponse) {
        isPremium = optimistic.isPremium
        premiumActivationPending = true
    }

    func confirmPremiumActivation(_ entitlement: UserEntitlementResponse?) {
        applyEntitlement(entitlement, activationPending: false)
    }

    func rollbackPremiumActivation() {
        isPremium = false
        premiumActivationPending = false
    }

    /// Rollback notifications must be account-attributed; unattributed or foreign IDs are ignored.
    static func shouldApplyRollbackNotification(currentUserId: String, notedUserId: String?) -> Bool {
        guard let notedUserId, !notedUserId.isEmpty, !currentUserId.isEmpty else { return false }
        return notedUserId == currentUserId
    }

    func refreshEntitlement() async {
        guard !userId.isEmpty, !accessToken.isEmpty else {
            isPremium = false
            premiumActivationPending = false
            return
        }
        StartupDiagnostics.track("entitlement_refresh_started", profilePresent: !profileId.isEmpty)
        let started = Date()
        do {
            let status = try await apiClient.fetchMySubscription(userId: userId, accessToken: accessToken)
            if status.entitlement?.isPremium == true {
                confirmPremiumActivation(status.entitlement)
            } else if premiumActivationPending {
                // Keep Activating through temporary /me lag; terminal reject rolls back elsewhere.
            } else {
                applyEntitlement(status.entitlement)
            }
            StartupDiagnostics.track(
                "entitlement_refresh_succeeded",
                success: true,
                durationMs: Int(Date().timeIntervalSince(started) * 1000),
                profilePresent: !profileId.isEmpty
            )
        } catch {
            StartupDiagnostics.track(
                "entitlement_refresh_failed",
                success: false,
                durationMs: Int(Date().timeIntervalSince(started) * 1000),
                errorCode: "transient"
            )
            // Keep current premium / Activating flag on transient errors.
        }
    }

    /// Single-flight startup prepare: location bootstrap + profile hydrate without blocking UI forever.
    struct SessionPrepareResult: Equatable {
        var profileReady: Bool
        var locationReady: Bool
        var locationAttempted: Bool
    }

    @discardableResult
    func prepareSessionForDataFetch(
        locationService: LocationProviding? = nil
    ) async -> SessionPrepareResult {
        let locationService = locationService ?? LocationService.shared
        if let inFlightPrepare {
            return await inFlightPrepare.value
        }
        let ownerUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        openProfileEnsureCycleIfNeeded()
        let task = Task { @MainActor [weak self] () -> SessionPrepareResult in
            guard let self else {
                return SessionPrepareResult(profileReady: false, locationReady: false, locationAttempted: false)
            }
            self.prepareSessionNestingDepth += 1
            defer { self.prepareSessionNestingDepth = max(0, self.prepareSessionNestingDepth - 1) }
            let abandoned = SessionPrepareResult(
                profileReady: false,
                locationReady: false,
                locationAttempted: false
            )
            let stillOwnedByCaller: () -> Bool = {
                !Task.isCancelled
                    && !ownerUserId.isEmpty
                    && self.userId.trimmingCharacters(in: .whitespacesAndNewlines) == ownerUserId
            }
            guard stillOwnedByCaller() else { return abandoned }

            let started = Date()
            StartupDiagnostics.track("session_restore_started", profilePresent: !self.profileId.isEmpty)
            var locationAttempted = false
            if !self.hasValidLocation {
                locationAttempted = true
                StartupDiagnostics.track("location_bootstrap_started")
                let ok = await self.bootstrapLocationFromDevice(locationService: locationService)
                guard stillOwnedByCaller() else { return abandoned }
                StartupDiagnostics.track(
                    "location_bootstrap_succeeded",
                    success: ok,
                    durationMs: Int(Date().timeIntervalSince(started) * 1000)
                )
            } else if self.displayPlaceName == nil || self.displayPlaceName?.isEmpty == true {
                // Instant chip from cache happens in init; resolve if missing.
                Task { await self.resolvePlaceNameIfNeeded() }
            }
            guard stillOwnedByCaller() else { return abandoned }
            StartupDiagnostics.track("profile_load_started", profilePresent: !self.profileId.isEmpty)
            let profileOutcome = await self.ensureProfileIdIfNeeded()
            guard stillOwnedByCaller() else { return abandoned }
            let profileOk = profileOutcome.isReady
            StartupDiagnostics.track(
                "profile_load_succeeded",
                success: profileOk,
                durationMs: Int(Date().timeIntervalSince(started) * 1000),
                profilePresent: profileOk
            )
            let result = SessionPrepareResult(
                profileReady: profileOk,
                locationReady: self.hasValidLocation,
                locationAttempted: locationAttempted
            )
            StartupDiagnostics.track(
                result.profileReady ? "startup_ready" : "startup_partial_ready",
                success: result.profileReady,
                durationMs: Int(Date().timeIntervalSince(started) * 1000),
                profilePresent: result.profileReady
            )
            return result
        }
        inFlightPrepare = task
        let result = await task.value
        if inFlightPrepare == task {
            inFlightPrepare = nil
        }
        return result
    }

    /// Debounced foreground refresh — does not block forever on location.
    func refreshOnForeground(locationService: LocationProviding? = nil) async {
        let locationService = locationService ?? LocationService.shared
        let now = Date()
        if let lastForegroundRefreshAt, now.timeIntervalSince(lastForegroundRefreshAt) < 8 {
            return
        }
        let ownerUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ownerUserId.isEmpty else { return }
        lastForegroundRefreshAt = now
        // New foreground activation opens a new ensure cycle unless prepare is already in flight
        // for this cold-start (join the existing cycle instead of wiping its memo).
        if inFlightPrepare == nil {
            beginExplicitProfileEnsureCycle()
        }
        StartupDiagnostics.track("dashboard_refresh_started", errorCode: "foreground")
        _ = await prepareSessionForDataFetch(locationService: locationService)
        // Auth may have switched while prepare was in flight — never attribute to the new account.
        guard userId.trimmingCharacters(in: .whitespacesAndNewlines) == ownerUserId else { return }
        await refreshEntitlement()
        guard userId.trimmingCharacters(in: .whitespacesAndNewlines) == ownerUserId else { return }
        // Prepare already owned profile ensure in this foreground cycle — Dashboard must
        // reload data only (typed context → skipProfileEnsure).
        postProfileLocationDidUpdate(source: .foregroundRefresh, attributedUserId: ownerUserId)
    }

    /// Posts `.profileLocationDidUpdate` with typed ensure-ownership context.
    private func postProfileLocationDidUpdate(
        source: ProfileLocationUpdateContext.Source,
        attributedUserId: String? = nil
    ) {
        let uid = (attributedUserId ?? userId).trimmingCharacters(in: .whitespacesAndNewlines)
        NotificationCenter.default.post(
            name: .profileLocationDidUpdate,
            object: ProfileLocationUpdateContext(source: source, userId: uid)
        )
    }

    /// Test seam: allow a later foreground refresh cycle without waiting wall-clock debounce.
    func resetForegroundRefreshDebounceForTests() {
        lastForegroundRefreshAt = nil
    }

    func expireSessionAfterAuthFailure() {
        guard !(userId.isEmpty && accessToken.isEmpty) else {
            return
        }
        cancelInFlightSessionPrepare()
        cancelInFlightProfileEnsure(clearOutcome: true)
        let ownershipGen = durableOwnershipGeneration
        let ownsDurable = durableOwnership.isCurrent(ownershipGen)
        let snapshotUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let global = APIClient.getAuthState()
        let ownsGlobalAuth = !snapshotUserId.isEmpty && global?.userId == snapshotUserId

        if ownsDurable {
            clearDurableSessionStorage()
            durableOwnership.releaseAfterOwnedClear(expectedGeneration: ownershipGen)
        }
        durableOwnershipGeneration = 0

        if ownsGlobalAuth || HealthKitService.shared.boundUserId == snapshotUserId {
            clearAccountPresentationState()
        } else {
            placeResolveGeneration &+= 1
            displayPlaceName = nil
            isResolvingPlaceName = false
            isPremium = false
            premiumActivationPending = false
        }

        suppressAPIClientAuthSync = true
        isHydratingFromStore = true
        userId = ""
        accessToken = ""
        refreshToken = ""
        profileId = ""
        selectedTab = 0
        authNotice = l("auth.session_expired")
        isHydratingFromStore = false
        suppressAPIClientAuthSync = false

        if ownsGlobalAuth {
            APIClient.setAuthState(nil)
        }
    }

    var hasValidLocation: Bool {
        GeoCoordinates.isValid(lat: latitude, lon: longitude)
    }

    func hydrateProfileLocation(from profile: UserProfile) {
        guard GeoCoordinates.isValid(lat: profile.homeLat, lon: profile.homeLon) else {
            return
        }
        if locationSource == .device && hasValidLocation {
            return
        }
        latitude = profile.homeLat
        longitude = profile.homeLon
        locationSource = .cached
        locationRevision += 1
        Task { await self.resolvePlaceNameIfNeeded() }
    }

    @discardableResult
    func applyDeviceLocation(lat: Double, lon: Double) async -> Bool {
        guard GeoCoordinates.isValid(lat: lat, lon: lon) else {
            return false
        }
        latitude = lat
        longitude = lon
        locationSource = .device
        locationRevision += 1
        // Bootstrap revisions belong to the open prepare/ensure cycle — do not start a new attempt.
        if prepareSessionNestingDepth > 0 || inFlightEnsureProfile != nil || profileEnsureCycleTerminal == nil {
            profileEnsureCycleLocationRevisions.insert(locationRevision)
        } else if !profileEnsureCycleLocationRevisions.contains(locationRevision) {
            // Post-terminal user/device move: legitimate new cycle.
            beginExplicitProfileEnsureCycle()
            profileEnsureCycleLocationRevisions.insert(locationRevision)
        }
        // Geocode immediately — do not await profile PATCH / health / premium.
        Task { await self.resolvePlaceNameIfNeeded() }
        // New users still need ensure before data fetch; existing profiles sync in background.
        if profileId.isEmpty {
            return await syncProfileLocationIfNeeded()
        }
        Task { _ = await self.syncProfileLocationIfNeeded() }
        return true
    }

    /// Reverse-geocode current coords into `displayPlaceName` (cached; non-blocking for other work).
    func resolvePlaceNameIfNeeded() async {
        guard hasValidLocation else { return }
        let userId = self.userId
        guard !userId.isEmpty else { return }
        let lat = latitude
        let lon = longitude
        placeResolveGeneration &+= 1
        let generation = placeResolveGeneration
        // Instant UI from same-account nearby cache.
        if let cached = await PlaceGeocodingService.shared.reusablePresentationName(
            userId: userId,
            lat: lat,
            lon: lon
        ) {
            displayPlaceName = cached
        }
        RuntimePerformanceProbe.begin("place_resolve")
        isResolvingPlaceName = true
        defer { isResolvingPlaceName = false }
        let name = await PlaceGeocodingService.shared.resolvePlaceName(
            lat: lat,
            lon: lon,
            userId: userId
        )
        // Ignore stale results after logout, account switch, or newer coordinate.
        guard generation == placeResolveGeneration else { return }
        guard self.userId == userId else { return }
        guard abs(self.latitude - lat) < 0.0005, abs(self.longitude - lon) < 0.0005 else { return }
        if let name, !name.isEmpty {
            displayPlaceName = name
            RuntimePerformanceProbe.end("place_resolve", success: true)
            postProfileLocationDidUpdate(source: .placeNameResolved)
        } else {
            RuntimePerformanceProbe.end("place_resolve", success: false, errorCode: "geocode_empty")
        }
    }

    func syncProfileLocationIfNeeded() async -> Bool {
        guard hasValidLocation, !userId.isEmpty, !accessToken.isEmpty else {
            return false
        }
        if profileId.isEmpty {
            return await ensureProfileIdIfNeeded().isReady
        }
        do {
            _ = try await apiClient.updateProfile(
                userId: userId,
                profileId: profileId,
                payload: ProfileUpdatePayload(
                    personaType: nil,
                    sensitivityLevel: nil,
                    homeLat: latitude,
                    homeLon: longitude,
                    dateOfBirth: nil
                ),
                accessToken: accessToken
            )
            postProfileLocationDidUpdate(source: .profileLocationSynced)
            return true
        } catch {
            return false
        }
    }

    func bootstrapLocationFromDevice(locationService: LocationProviding? = nil) async -> Bool {
        let locationService = locationService ?? LocationService.shared
        locationService.refreshAuthorizationStatus()
        switch locationService.authorizationStatus {
        case .notDetermined:
            locationService.requestWhenInUseAuthorization()
            return false
        case .denied, .restricted:
            return false
        default:
            break
        }
        do {
            let location = try await locationService.fetchCurrentLocation()
            return await applyDeviceLocation(
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude
            )
        } catch {
            return false
        }
    }

    @discardableResult
    func ensureProfileIdIfNeeded() async -> ProfileEnsureOutcome {
        openProfileEnsureCycleIfNeeded()
        if let memoized = memoizedProfileEnsureOutcomeForCurrentCycle() {
            lastProfileEnsureOutcome = memoized
            return memoized
        }
        if let inFlightEnsureProfile {
            return await inFlightEnsureProfile.value
        }
        let task = Task { @MainActor [weak self] () -> ProfileEnsureOutcome in
            guard let self else { return .needsAuthentication }
            return await self.performEnsureProfileIdIfNeeded()
        }
        inFlightEnsureProfile = task
        let outcome = await task.value
        if inFlightEnsureProfile == task {
            inFlightEnsureProfile = nil
        }
        return outcome
    }

    private func performEnsureProfileIdIfNeeded() async -> ProfileEnsureOutcome {
        if !profileId.isEmpty {
            lastProfileEnsurePhase = .idle
            lastProfileEnsureOutcome = .ready
            lastProfileEnsureCompletedAt = Date()
            storeProfileEnsureCycleTerminal(.ready)
            return .ready
        }
        guard !userId.isEmpty, !accessToken.isEmpty else {
            let outcome = ProfileEnsureOutcome.needsAuthentication
            lastProfileEnsurePhase = .list
            lastProfileEnsureOutcome = outcome
            lastProfileEnsureCompletedAt = Date()
            storeProfileEnsureCycleTerminal(outcome)
            ProductAnalytics.track(
                "profile_ensure_failed",
                properties: ProfileEnsureMapper.analyticsProperties(
                    for: nil,
                    outcome: outcome,
                    phase: .list
                )
            )
            return outcome
        }

        let requestedUserId = userId
        var requestedAccessToken = accessToken
        let ensureGeneration = profileEnsureGeneration
        profileEnsureCycleAttemptCount += 1
        isEnsuringProfile = true
        defer {
            if ensureGeneration == profileEnsureGeneration {
                isEnsuringProfile = false
            }
        }

        var phase: ProfileEnsurePhase = .list
        lastProfileEnsurePhase = phase
        do {
            requestedAccessToken = ensureAccessToken(
                requestedUserId: requestedUserId,
                fallback: requestedAccessToken
            )
            let profiles = try await apiClient.listProfiles(
                userId: requestedUserId,
                accessToken: requestedAccessToken
            )
            guard isCurrentProfileEnsureContext(
                userId: requestedUserId,
                accessToken: requestedAccessToken,
                generation: ensureGeneration
            ) else {
                return .needsAuthentication
            }
            if let existing = profiles.first {
                profileId = existing.id
                hydrateProfileLocation(from: existing)
                lastProfileEnsureOutcome = .ready
                lastProfileEnsureCompletedAt = Date()
                storeProfileEnsureCycleTerminal(.ready)
                ProductAnalytics.track(
                    "profile_ensure_succeeded",
                    properties: ["source": "list", "phase": phase.rawValue, "diagnostic_code": "PE_READY"]
                )
                return .ready
            }
            phase = .locationGate
            lastProfileEnsurePhase = phase
            if !hasValidLocation {
                // One device bootstrap before declaring needsLocation — CTA should not
                // require a separate location tap when permission is already granted.
                _ = await bootstrapLocationFromDevice()
            }
            guard isCurrentProfileEnsureContext(
                userId: requestedUserId,
                accessToken: requestedAccessToken,
                generation: ensureGeneration
            ) else {
                return .needsAuthentication
            }
            guard hasValidLocation else {
                let outcome = ProfileEnsureOutcome.needsLocation
                lastProfileEnsureOutcome = outcome
                lastProfileEnsureCompletedAt = Date()
                storeProfileEnsureCycleTerminal(outcome)
                ProductAnalytics.track(
                    "profile_ensure_failed",
                    properties: ProfileEnsureMapper.analyticsProperties(
                        for: nil,
                        outcome: outcome,
                        phase: phase
                    )
                )
                return outcome
            }
            phase = .create
            lastProfileEnsurePhase = phase
            // Normalize persona/sensitivity to API enums before create.
            let personaValue = Self.normalizedPersona(persona)
            let sensitivityValue = Self.normalizedSensitivity(sensitivity)
            do {
                requestedAccessToken = ensureAccessToken(
                    requestedUserId: requestedUserId,
                    fallback: requestedAccessToken
                )
                let created = try await apiClient.createProfile(
                    userId: requestedUserId,
                    payload: ProfileCreatePayload(
                        personaType: personaValue,
                        sensitivityLevel: sensitivityValue,
                        homeLat: latitude,
                        homeLon: longitude,
                        dateOfBirth: dateOfBirth.map { Self.birthDateFormatter.string(from: $0) }
                    ),
                    accessToken: requestedAccessToken
                )
                guard isCurrentProfileEnsureContext(
                    userId: requestedUserId,
                    accessToken: requestedAccessToken,
                    generation: ensureGeneration
                ) else {
                    return .needsAuthentication
                }
                profileId = created.id
                postProfileLocationDidUpdate(source: .profileCreated)
                lastProfileEnsureOutcome = .ready
                lastProfileEnsureCompletedAt = Date()
                storeProfileEnsureCycleTerminal(.ready)
                ProductAnalytics.track(
                    "profile_ensure_succeeded",
                    properties: ["source": "create", "phase": phase.rawValue, "diagnostic_code": "PE_READY"]
                )
                return .ready
            } catch {
                // Create may have succeeded server-side while list lagged, or returned conflict.
                // One recovery list prevents false failure after create success + delayed consistency.
                requestedAccessToken = ensureAccessToken(
                    requestedUserId: requestedUserId,
                    fallback: requestedAccessToken
                )
                if isCurrentProfileEnsureContext(
                    userId: requestedUserId,
                    accessToken: requestedAccessToken,
                    generation: ensureGeneration
                ),
                   let recovered = try? await apiClient.listProfiles(
                    userId: requestedUserId,
                    accessToken: requestedAccessToken
                   ),
                   let existing = recovered.first {
                    profileId = existing.id
                    hydrateProfileLocation(from: existing)
                    lastProfileEnsureOutcome = .ready
                    lastProfileEnsureCompletedAt = Date()
                    storeProfileEnsureCycleTerminal(.ready)
                    ProductAnalytics.track(
                        "profile_ensure_succeeded",
                        properties: [
                            "source": "create_recover_list",
                            "phase": phase.rawValue,
                            "diagnostic_code": "PE_READY",
                        ]
                    )
                    return .ready
                }
                throw error
            }
        } catch is CancellationError {
            // Do not sticky-write UI error for abandoned/cancelled ensure work.
            lastProfileEnsurePhase = phase
            lastProfileEnsureCompletedAt = Date()
            return .needsAuthentication
        } catch {
            guard isCurrentProfileEnsureContext(
                userId: requestedUserId,
                accessToken: requestedAccessToken,
                generation: ensureGeneration
            ) else {
                return .needsAuthentication
            }
            let outcome = ProfileEnsureMapper.outcome(for: error)
            lastProfileEnsureOutcome = outcome
            lastProfileEnsurePhase = phase
            lastProfileEnsureCompletedAt = Date()
            storeProfileEnsureCycleTerminal(outcome)
            if case .needsAuthentication = outcome {
                expireSessionAfterAuthFailure()
            } else if case .failure(let reason) = outcome, reason.suggestsReauthentication {
                expireSessionAfterAuthFailure()
            }
            ProductAnalytics.track(
                "profile_ensure_failed",
                properties: ProfileEnsureMapper.analyticsProperties(
                    for: error,
                    outcome: outcome,
                    phase: phase
                )
            )
            return outcome
        }
    }

    static func normalizedPersona(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowed = Set(["adult", "child", "elderly", "asthma", "allergy", "runner", "worker"])
        return allowed.contains(value) ? value : "adult"
    }

    static func normalizedSensitivity(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowed = Set(["low", "medium", "high"])
        return allowed.contains(value) ? value : "medium"
    }

    /// Ownership policy for shared durable session fields:
    /// - Auth credentials (`userId`/`email`/`accessToken`/`refreshToken`): owner-only write/clear.
    /// - Account-scoped (`profileId`/`persona`/`sensitivity`/location/`dateOfBirth`/checklist*):
    ///   owner-only write; stale AppSession must not overwrite account B.
    /// - Device UX prefs (`onboardingCompleted`/`preferredLanguage`): still owner-gated so a
    ///   stale logout/didSet cannot clobber the signed-in account's durable prefs.
    private func persist() {
        guard !isHydratingFromStore else { return }

        let hasFullAuth = !userId.isEmpty && !accessToken.isEmpty && !refreshToken.isEmpty
        if durableOwnership.isCurrent(durableOwnershipGeneration) {
            writeDurableSessionFields()
        } else if hasFullAuth {
            // Claim only when store is unowned or already records this same userId.
            // Never steal durable ownership from a different account B.
            let owner = durableOwnership.ownerUserId
            if owner.isEmpty || owner == userId {
                durableOwnershipGeneration = durableOwnership.claim(userId: userId)
                writeDurableSessionFields()
            }
        }
        // else: stale instance — in-memory only; do not mutate shared store.

        syncAPIClientAuthFromPersist()
    }

    private func writeDurableSessionFields() {
        defaults.set(onboardingCompleted, forKey: Keys.onboardingCompleted)
        defaults.set(profileId, forKey: Keys.profileId)
        defaults.set(persona, forKey: Keys.persona)
        defaults.set(sensitivity, forKey: Keys.sensitivity)
        defaults.set(preferredLanguage, forKey: Keys.preferredLanguage)
        defaults.set(latitude, forKey: Keys.latitude)
        defaults.set(longitude, forKey: Keys.longitude)
        defaults.set(locationSource.rawValue, forKey: Keys.locationSource)
        // City presentation is account-scoped in PlaceGeocodingService — do not persist globally.
        defaults.removeObject(forKey: Keys.displayPlaceName)
        if let dateOfBirth {
            defaults.set(Self.birthDateFormatter.string(from: dateOfBirth), forKey: Keys.dateOfBirth)
        } else {
            defaults.removeObject(forKey: Keys.dateOfBirth)
        }
        defaults.set(Array(checklistCompletedItems).sorted(), forKey: Keys.checklistCompletedItems)
        defaults.set(checklistHidden, forKey: Keys.checklistHidden)
        if userId.isEmpty {
            credentials.deleteValue(forKey: Keys.userId)
        } else {
            credentials.setString(userId, forKey: Keys.userId)
        }
        if email.isEmpty {
            credentials.deleteValue(forKey: Keys.email)
        } else {
            credentials.setString(email, forKey: Keys.email)
        }
        if accessToken.isEmpty {
            credentials.deleteValue(forKey: Keys.accessToken)
        } else {
            credentials.setString(accessToken, forKey: Keys.accessToken)
        }
        if refreshToken.isEmpty {
            credentials.deleteValue(forKey: Keys.refreshToken)
        } else {
            credentials.setString(refreshToken, forKey: Keys.refreshToken)
        }
    }

    /// Owning logout / auth-expiry durable clear. Caller must hold a current ownership generation.
    private func clearDurableSessionStorage() {
        credentials.deleteValue(forKey: Keys.userId)
        credentials.deleteValue(forKey: Keys.email)
        credentials.deleteValue(forKey: Keys.accessToken)
        credentials.deleteValue(forKey: Keys.refreshToken)
        defaults.removeObject(forKey: Keys.userId)
        defaults.removeObject(forKey: Keys.email)
        defaults.removeObject(forKey: Keys.accessToken)
        defaults.removeObject(forKey: Keys.refreshToken)
        defaults.removeObject(forKey: Keys.profileId)
        defaults.removeObject(forKey: Keys.dateOfBirth)
        defaults.removeObject(forKey: Keys.displayPlaceName)
        defaults.set(0.0, forKey: Keys.latitude)
        defaults.set(0.0, forKey: Keys.longitude)
        defaults.set(LocationSource.unknown.rawValue, forKey: Keys.locationSource)
        // persona / sensitivity / checklist / onboarding / language stay as last owner values
        // until a new owner writes — stale logout must not reset them to A's blanks.
    }

    private func syncAPIClientAuthFromPersist() {
        guard !suppressAPIClientAuthSync else { return }
        // Access token + userId are enough for authenticated API calls.
        // Refresh may be empty briefly after some auth paths; do not skip sync.
        if userId.isEmpty || accessToken.isEmpty {
            return
        }
        if let global = APIClient.getAuthState(),
           !global.userId.isEmpty,
           global.userId != userId {
            // Stale AppSession must not overwrite a newer account's APIClient auth.
            return
        }
        let refresh = refreshToken.isEmpty
            ? (APIClient.getAuthState()?.refreshToken ?? "")
            : refreshToken
        APIClient.setAuthState(
            APIClient.AuthState(
                userId: userId,
                accessToken: accessToken,
                refreshToken: refresh
            )
        )
    }

    private func restoreSupabaseSession() async {
        do {
            guard let session = try await supabaseAuth.restoreSessionIfNeeded() else {
                return
            }
            userId = session.userId
            email = session.email
            accessToken = session.accessToken
            refreshToken = session.refreshToken
            authNotice = ""
        } catch {
            // Keep local session as source of truth when restore fails.
        }
    }
}

enum HiAirL10n {
    static func t(_ key: String, lang: String) -> String {
        let language = normalizedLanguageCode(lang)
        return strings[language]?[key] ?? strings["ru"]?[key] ?? key
    }

    private static func normalizedLanguageCode(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.hasPrefix("fr") { return "fr" }
        if lower.hasPrefix("it") { return "it" }
        if lower.hasPrefix("es") { return "es" }
        if lower.hasPrefix("en") { return "en" }
        return "ru"
    }

    private static let strings: [String: [String: String]] = {
        var all = baseStrings
        let english = baseStrings["en"] ?? [:]
        for code in ["es", "it", "fr"] {
            all[code] = english.merging(localizedOverrides[code] ?? [:]) { _, new in new }
        }
        return all
    }()

    private static let baseStrings: [String: [String: String]] = [
        "ru": [
            "title.settings": "Настройки",
            "tab.dashboard": "Главная",
            "tab.planner": "План",
            "tab.insights": "Инсайты",
            "insights.empty": "Логируй симптомы, чтобы открыть персональные паттерны.",
            "insights.unlock_more": "Логируй еще 5 дней, и появятся паттерны.",
            "insights.failed": "Не удалось загрузить инсайты.",
            "insights.count": "инсайтов",
            "insights.loading": "Загружаем персональные паттерны...",
            "insights.retry": "Попробовать снова",
            "insights.progress_title": "Прогресс к инсайтам",
            "insights.next_step": "Что сделать сейчас",
            "insights.next.log_symptoms": "Записать симптомы сегодня",
            "insights.next.open_planner": "Обновить план дня",
            "insights.refresh": "Обновить инсайты",
            "insights.sample_size": "На основе %d наблюдений",
            "insights.window.title": "Период анализа",
            "insights.window.7d": "7 дней",
            "insights.window.30d": "30 дней",
            "insights.section.today": "Сегодня",
            "insights.section.trends": "Тренды: сон, активность и восстановление",
            "insights.section.trends.empty": "Пока недостаточно данных для трендов.",
            "insights.section.associations": "Связи: среда, сон, нагрузка и симптомы",
            "insights.section.associations.empty": "Связи появятся после нескольких дней журнала.",
            "insights.section.forecast": "Что учесть сегодня",
            "insights.section.recommendations": "Рекомендации на основе ваших данных",
            "insights.section.insufficient": "Данных пока недостаточно",
            "insights.section.health_status": "Статус данных здоровья",
            "insights.section.premium_patterns": "Расширенные паттерны",
            "insights.health_status": "Дней с метриками: %d · %@",
            "insights.health_status_unknown": "Данные здоровья ещё не синхронизированы.",
            "insights.sync.ok": "синхронизация в порядке",
            "insights.sync.partial": "частичная синхронизация",
            "insights.sync.pending": "синхронизация продолжается",
            "insights.sync.error": "ошибка синхронизации",
            "insights.sync.unknown": "статус синхронизации неизвестен",
            "insights.progress_days": "%d из %d дней с данными",
            "symptoms.severity.mild": "Легко",
            "symptoms.severity.moderate": "Средне",
            "symptoms.severity.severe": "Сильно",
            "symptoms.unknown": "Симптом",
            "symptoms.frequency": "Частота",
            "symptoms.frequency.any": "Не указано",
            "symptoms.frequency.once": "Один раз",
            "symptoms.frequency.intermittent": "Периодически",
            "symptoms.frequency.constant": "Постоянно",
            "symptoms.duration": "Длительность",
            "symptoms.duration.any": "Не указано",
            "symptoms.duration.15m": "До 15 мин",
            "symptoms.duration.1h": "Около часа",
            "symptoms.duration.3h": "Несколько часов",
            "symptoms.duration.day": "Весь день",
            "symptoms.ongoing": "Всё ещё продолжается",
            "symptoms.activity": "Активность в момент начала",
            "symptoms.activity.any": "Не указано",
            "symptoms.activity.rest": "Отдых",
            "symptoms.activity.walk": "Прогулка",
            "symptoms.activity.exercise": "Тренировка",
            "symptoms.activity.work": "Работа",
            "symptoms.activity.sleep": "Сон",
            "symptoms.hydration": "Гидратация",
            "symptoms.hydration.any": "Не указано",
            "symptoms.hydration.low": "Мало воды",
            "symptoms.hydration.ok": "Достаточно",
            "symptoms.hydration.high": "Много воды",
            "symptoms.medication": "Принимал(а) лекарство",
            "symptoms.trigger_optional": "Возможный триггер (опционально)",
            "symptoms.taxonomy_failed": "Не удалось загрузить список симптомов. Проверьте соединение и попробуйте снова.",
            "symptoms.headline": "Как вы себя чувствуете?",
            "symptoms.loading": "Загружаем симптомы…",
            "symptoms.check_connection": "Проверить подключение",
            "symptoms.recents": "Недавние",
            "symptoms.categories": "Категории",
            "symptoms.history": "История",
            "symptoms.history_empty": "Пока нет записей — отметьте первый симптом.",
            "symptoms.today": "Сегодня",
            "symptoms.yesterday": "Вчера",
            "symptoms.edit": "Изменить",
            "symptoms.delete": "Удалить",
            "symptoms.delete_confirm": "Удалить эту запись симптома?",
            "symptoms.deleted": "Запись удалена.",
            "symptoms.more_details": "Подробнее",
            "symptoms.no_search_results": "Ничего не найдено. Попробуйте другое название.",
            "symptoms.cached_offline": "Показан сохранённый список (офлайн).",
            "symptoms.add_custom": "Добавить свой симптом",
            "symptoms.custom_label": "Название симптома",
            "symptoms.custom_added": "Свой симптом добавлен.",
            "symptoms.entry_title": "Запись симптома",
            "symptoms.onset": "Когда началось",
            "symptoms.clear_search": "Очистить",
            "symptoms.red_flag_hint": "Важный сигнал самочувствия — при необходимости обратитесь за помощью.",
            "common.cancel": "Отмена",
            "insights.today.steps": "Шаги: %d",
            "insights.today.sleep": "Сон: %d мин",
            "insights.today.rhr": "Пульс в покое: %d",
            "insights.today.hrv": "HRV: %d мс",
            "insights.today.spo2": "SpO₂: %d%%",
            "insights.today.resp": "Дыхание: %d/мин",
            "insights.today.empty": "Нет данных за сегодня — подключите Apple Health или отметьте симптомы.",
            "insights.confidence.preliminary": "Уверенность: предварительная",
            "insights.confidence.moderate": "Уверенность: умеренная",
            "insights.confidence.stronger": "Уверенность: выше",
            "insights.confidence.insufficient": "Уверенность: недостаточно данных",
            "wearable.health.error.locked": "Apple Health временно недоступен (устройство заблокировано). Повторим синхронизацию позже.",
            "settings.briefing_setup_hint": "Сначала войдите в аккаунт, чтобы настроить «Утренний брифинг».",
            "tab.symptoms": "Симптомы",
            "tab.settings": "Настройки",
            "auth.title": "Аккаунт HiAir",
            "auth.subtitle": "Breathe better. Live better.",
            "brand.tagline": "Breathe better. Live better.",
            "auth.email": "Email",
            "auth.password": "Пароль (мин. 12 символов, A/a/0-9/символ)",
            "auth.sign_up": "Регистрация",
            "auth.signing_up": "Регистрируем...",
            "auth.log_in": "Войти",
            "auth.sign_in_apple": "Войти через Apple",
            "auth.sign_in_google": "Войти через Google",
            "auth.logging_in": "Входим...",
            "auth.enter_email": "Введите email.",
            "auth.password_short": "Пароль должен быть не короче 12 символов.",
            "auth.session_expired": "Сессия истекла. Войдите снова.",
            "auth.ok": "Авторизация успешна.",
            "auth.email_conflict": "Пользователь с таким email уже существует.",
            "auth.backend_unreachable": "Нет подключения к серверу. Проверьте интернет и повторите.",
            "auth.backend_unavailable": "Backend временно недоступен. Проверьте подключение к базе данных.",
            "auth.confirm_email": "Мы отправили письмо на %@. Откройте ссылку в письме, затем нажмите «Войти» с тем же паролем.",
            "auth.confirm_email_short": "Подтвердите email, затем войдите.",
            "auth.oauth_continue": "Завершите вход в браузере, затем вернитесь в HiAir.",
            "auth.cancelled": "Вход отменён.",
            "auth.fail": "Ошибка авторизации.",
            "auth.server_error": "Ошибка сервера (%d). Повторите позже.",
            "auth.oauth_not_configured": "Вход через %@ пока не настроен на сервере. Используйте email и пароль или обновите приложение позже.",
            "auth.rate_limited": "Слишком много попыток. Подождите 15 минут и повторите вход.",
            "auth.bridge_unreachable": "Сервер авторизации временно недоступен. Повторите через минуту.",
            "auth.working": "Подключаемся к серверу…",
            "auth.bad_response": "Некорректный ответ сервера. Обновите приложение или повторите позже.",
            "onboarding.title": "Онбординг HiAir",
            "onboarding.persona": "Профиль",
            "onboarding.sensitivity": "Чувствительность",
            "onboarding.latitude": "Широта",
            "onboarding.longitude": "Долгота",
            "onboarding.profile_id": "Profile ID (необязательно)",
            "onboarding.continue": "Продолжить",
            "onboarding.next": "Далее",
            "onboarding.back": "Назад",
            "onboarding.start": "Начать",
            "onboarding.step1.title": "HiAir — помощник по жаре и качеству воздуха",
            "onboarding.step1.body": "HiAir помогает понять, когда жара и воздух на улице могут быть небезопасны именно для вас.",
            "onboarding.step2.title": "Какие проблемы решает HiAir",
            "onboarding.problem.heat": "Жара и риск перегрева",
            "onboarding.problem.pm25": "Плохой воздух и мелкие частицы",
            "onboarding.problem.ozone": "Озон, дым и загрязнение",
            "onboarding.problem.sensitive": "Дети, пожилые, астма и аллергия",
            "onboarding.problem.outdoor": "Спорт, прогулки и работа на улице",
            "onboarding.step3.title": "Для кого вы используете HiAir?",
            "onboarding.for_self": "Для себя",
            "onboarding.for_child": "Для ребёнка",
            "onboarding.for_elderly": "Для пожилого человека",
            "onboarding.for_asthma": "Астма / дыхание",
            "onboarding.for_allergy": "Аллергия",
            "onboarding.for_runner": "Бег / спорт",
            "onboarding.for_worker": "Работа на улице",
            "onboarding.step4.title": "Что смотреть каждый день",
            "onboarding.look.risk": "Индекс риска показывает общую оценку воздуха для вас сейчас",
            "onboarding.look.hourly": "Прогноз по часам показывает безопасные окна",
            "onboarding.look.recommendations": "Рекомендации объясняют, что делать",
            "onboarding.look.notifications": "Уведомления предупреждают заранее",
            "onboarding.step5.title": "Почему нужны разрешения",
            "onboarding.permissions.location.title": "Геолокация",
            "onboarding.permissions.location.body": "HiAir использует местоположение, чтобы рассчитывать риск жары и качества воздуха для вашей текущей зоны.",
            "onboarding.permissions.notifications.title": "Уведомления",
            "onboarding.permissions.notifications.body": "Уведомления нужны, чтобы предупредить о жаре или плохом воздухе заранее.",
            "onboarding.permissions.allow": "Разрешить",
            "onboarding.permissions.later": "Настроить позже",
            "onboarding.step6.title": "Готово",
            "onboarding.step6.body": "Теперь откройте главный экран, посмотрите текущий риск, рекомендации и безопасные часы на сегодня.",
            "onboarding.open_forecast": "Открыть мой прогноз",
            "wearable.consent.title": "Подключите здоровье и активность",
            "wearable.consent.body": "HiAir точнее оценивает нагрузку в жару и при плохом воздухе. С вашего разрешения мы используем шаги, расстояние, калории, пульс, HRV, сон и стадии сна, SpO₂, дыхание, температуру и тренировки — только в агрегированном виде для wellness-подсказок.",
            "wearable.consent.disclaimer": "HiAir не ставит диагнозы и не заменяет врача.",
            "wearable.consent.connect": "Подключить",
            "wearable.consent.skip": "Пропустить",
            "wearable.consent.saving": "Сохраняем подключение…",
            "wearable.consent.failed": "Не удалось сохранить согласие. Повторите попытку.",
            "wearable.consent.retry": "Повторить",
            "wearable.consent.connected": "Здоровье подключено",
            "wearable.consent.revoking": "Отключаем здоровье…",
            "wearable.consent.revoke_failed": "Не удалось завершить отключение на сервере. Повторите.",
            "wearable.dashboard.title": "Нагрузка сегодня",
            "wearable.dashboard.steps": "Шаги",
            "wearable.dashboard.hr_normal": "Пульс: в норме",
            "wearable.dashboard.hr_elevated": "Пульс: выше обычного",
            "wearable.dashboard.hr_unknown": "Пульс: данных мало",
            "wearable.dashboard.hr_bpm": "Пульс: %d уд/мин",
            "wearable.dashboard.hr_elevated_bpm": "Пульс: %d уд/мин (выше обычного)",
            "wearable.dashboard.rhr_bpm": "Пульс в покое: %d уд/мин",
            "wearable.dashboard.load_risk": "Риск нагрузки",
            "wearable.dashboard.not_connected": "Подключите здоровье, чтобы HiAir точнее оценивал нагрузку в жару.",
            "wearable.dashboard.denied": "Доступ к Apple Health отключён.",
            "wearable.dashboard.open_settings": "Открыть настройки",
            "wearable.dashboard.open_health": "Открыть «Здоровье»",
            "wearable.dashboard.health_path": "В приложении «Здоровье»: Профиль → Конфиденциальность → Приложения → HiAir → включите Шаги и Пульс.",
            "wearable.dashboard.unavailable": "Сегодня пока мало данных. Анализ основан на погоде и качестве воздуха.",
            "wearable.health.error.unavailable_device": "Apple Health недоступен на этом устройстве.",
            "wearable.health.error.no_types": "HealthKit не настроен в приложении (нет типов данных).",
            "wearable.health.error.missing_plist": "В этой сборке нет HealthKit privacy strings. Нужен новый TestFlight build.",
            "wearable.health.error.missing_entitlement": "Сборка подписана без HealthKit. В Developer Portal включите HealthKit для com.hiair.app, затем пересоберите TestFlight.",
            "wearable.health.error.denied": "Apple Health не дал доступ. Откройте «Здоровье» и включите данные для HiAir.",
            "wearable.health.error.generic": "Ошибка Apple Health: %@",
            "wearable.health.build_label": "Сборка iOS %@",
            "wearable.load.none": "нет данных",
            "wearable.load.low": "низкий",
            "wearable.load.moderate": "средний",
            "wearable.load.elevated": "повышенный",
            "settings.wearables.title": "Здоровье и активность",
            "settings.wearables.status": "Apple Health",
            "settings.wearables.connect": "Подключить Apple Health",
            "health.today.title": "Показатели здоровья сегодня",
            "health.today.empty": "Данные ещё синхронизируются. Загляните после прогулки или сна.",
            "health.today.sleep_stages": "Сон по стадиям",
            "health.sleep.total": "Сон всего",
            "health.sleep.deep": "Глубокий сон",
            "health.sleep.rem": "REM",
            "health.sleep.core": "Лёгкий сон",
            "health.sleep.awake": "Бодрствование",
            "health.sleep.in_bed": "В постели",
            "health.unit.min": "мин",
            "health.unit.km": "км",
            "health.unit.kcal": "ккал",
            "health.unit.bpm": "уд/мин",
            "health.unit.ms": "мс",
            "health.unit.celsius": "°C",
            "health.metric.steps": "Шаги",
            "health.metric.distance_walking_running": "Дистанция",
            "health.metric.active_energy": "Активные калории",
            "health.metric.exercise_minutes": "Минуты активности",
            "health.metric.stand_minutes": "Минуты стояния",
            "health.metric.flights_climbed": "Этажи",
            "health.metric.workout_count": "Тренировки",
            "health.metric.workout_duration": "Время тренировок",
            "health.metric.heart_rate": "Пульс",
            "health.metric.resting_heart_rate": "Пульс в покое",
            "health.metric.walking_heart_rate_avg": "Пульс при ходьбе",
            "health.metric.basal_energy": "Базовая энергия",
            "health.metric.walking_speed": "Скорость ходьбы",
            "health.metric.walking_step_length": "Длина шага",
            "health.metric.walking_asymmetry": "Асимметрия ходьбы",
            "health.metric.walking_double_support": "Двойная опора",
            "health.metric.mindfulness_minutes": "Осознанность",
            "health.metric.hrv_sdnn": "Вариабельность пульса",
            "health.metric.respiratory_rate": "Дыхание",
            "health.metric.oxygen_saturation": "Насыщение кислородом",
            "health.metric.body_temperature": "Температура тела",
            "health.metric.wrist_temperature": "Температура запястья",
            "health.metric.vo2_max": "VO₂ max",
            "insights.premium_locked.title": "Персональная аналитика — в Premium",
            "insights.premium_locked.body": "Откроются тренды здоровья, возможные связи с воздухом и понятные рекомендации, что делать сегодня.",
            "insights.premium_locked.cta": "Смотреть Premium",
            "insights.today.distance": "Дистанция: %.1f км",
            "insights.today.energy": "Калории: %d",
            "insights.today.vo2": "VO₂ max: %d",
            "insights.today.workouts": "Тренировки: %d",
            "planner.premium_required": "Почасовой план дня доступен в Premium — безопасные окна и вентиляция на весь день.",
            "planner.premium_locked.title": "План дня — в Premium",
            "paywall.catalog_help": "Планы подписки сейчас недоступны в App Store. Проверьте соединение и повторите попытку чуть позже.",
            "settings.wearables.connected": "подключено",
            "settings.wearables.device_authorized": "доступ разрешён",
            "settings.wearables.consent_inactive": "согласие неактивно",
            "settings.wearables.denied": "доступ отключён",
            "settings.wearables.disconnect": "Отключить",
            "settings.wearables.delete": "Удалить health-данные",
            "settings.wearables.delete_done": "Локальные health-данные удалены",
            "settings.wearables.delete_confirm": "Удалить все сохранённые health-данные?",
            "common.loading": "Загрузка…",
            "common.retry": "Повторить",
            "common.error.title": "Не удалось загрузить",
            "common.error.network": "Проверьте интернет и попробуйте снова.",
            "state.empty.title": "Пока нет данных",
            "state.empty.body": "Когда появятся данные, HiAir покажет понятный результат и следующий шаг.",
            "state.empty.insights.title": "Мало записей для инсайтов",
            "state.empty.insights.body": "Ведите симптомы ещё несколько дней — так HiAir найдёт личные паттерны.",
            "state.loading": "Загрузка…",
            "status.excellent": "Отлично",
            "status.good": "Хорошо",
            "status.moderate": "Умеренно",
            "status.bad": "Плохо",
            "dashboard.title": "Ежедневный воздушный интеллект",
            "dashboard.subtitle": "Риск, алерты и AI-инсайты в одном месте.",
            "dashboard.greeting": "Ваш воздух сегодня",
            "dashboard.greeting_neutral": "Ваш воздух сегодня",
            "dashboard.improving": "Персональные рекомендации на основе текущих условий.",
            "dashboard.improving_neutral": "Персональные рекомендации на основе текущих условий.",
            "dashboard.current_risk": "Текущий риск",
            "dashboard.current_risk_title": "Текущий риск",
            "dashboard.badge_moderate": "УМЕРЕННЫЙ",
            "dashboard.reason_unavailable": "Объяснение пока недоступно.",
            "dashboard.location": "Ваш район",
            "dashboard.location_unknown": "Локация не задана",
            "dashboard.weather_title": "Условия сегодня",
            "dashboard.weather_unavailable": "Погодные данные недоступны",
            "dashboard.freshness_fresh": "Обновлено",
            "dashboard.freshness_stale": "Обновить",
            "dashboard.freshness_updating": "Обновляем…",
            "dashboard.source_estimated": "Оценка по ближайшим данным",
            "dashboard.profile_button": "Профиль",
            "dashboard.no_safe_window": "Нет безопасных окон в ближайшие часы.",
            "dashboard.no_safe_windows": "В ближайшие часы безопасных окон нет.",
            "dashboard.error": "Не удалось загрузить данные.",
            "dashboard.empty.no_profile.title": "Профиль не настроен",
            "dashboard.empty.no_profile.body": "Без профиля невозможно персонально рассчитать риск и безопасные окна.",
            "dashboard.empty.no_profile.cta": "Создать профиль автоматически",
            "profile.ensure.creating": "Создаём профиль…",
            "profile.ensure.needs_location": "Нужна геолокация, чтобы создать профиль. Разрешите доступ или обновите местоположение.",
            "profile.ensure.failed": "Не удалось создать профиль. Проверьте соединение и повторите.",
            "profile.ensure.decode": "Ответ сервера не распознан. Обновите приложение или повторите позже.",
            "profile.ensure.transport": "Не удалось связаться с сервером. Проверьте сеть и повторите.",
            "profile.ensure.cancelled": "Создание профиля прервано. Нажмите ещё раз.",
            "profile.ensure.unavailable": "Сервис временно недоступен. Повторите через минуту.",
            "profile.ensure.offline": "Нет сети. Проверьте интернет и повторите.",
            "profile.ensure.forbidden": "Нет доступа к профилю. Войдите снова или обратитесь в поддержку.",
            "profile.ensure.premium_required": "Достигнут лимит профилей. Оформите Premium, чтобы добавить ещё.",
            "profile.ensure.retry": "Повторить",
            "auth.sign_in": "Войти",
            "dashboard.empty.api_unavailable": "Данные временно недоступны. Проверьте интернет и попробуйте снова.",
            "dashboard.empty.location_missing": "Доступ к геолокации выключен. Включите его в Настройках или повторите запрос.",
            "location.denied.title": "Геолокация выключена",
            "location.denied.body": "HiAir использует ваше местоположение, чтобы рассчитывать риск жары и качества воздуха для текущей зоны.",
            "location.open_settings": "Открыть настройки",
            "location.retry": "Повторить",
            "location.services_disabled": "Службы геолокации отключены на устройстве.",
            "location.timeout": "Не удалось определить местоположение. Попробуйте ещё раз.",
            "dashboard.recommended_actions": "Рекомендуемые действия",
            "dashboard.no_actions": "Нет доступных действий.",
            "dashboard.safe_window": "Безопасное окно",
            "dashboard.safe_windows": "Безопасные окна",
            "dashboard.safe_windows_tooltip": "Период дня, когда условия более безопасны для прогулки, спорта или проветривания.",
            "dashboard.auto_updates": "Автообновление по прогнозу",
            "dashboard.mood_prefix": "Состояние",
            "dashboard.mood.calm": "Спокойно",
            "dashboard.mood.aware": "Внимательно",
            "dashboard.mood.cautious": "Осторожно",
            "dashboard.mood.protective": "Защита",
            "dashboard.do_now": "Сделать сейчас",
            "dashboard.recommendations_tooltip": "Персональные советы на основе текущего риска и вашего профиля.",
            "dashboard.recompute": "Пересчитать риск сейчас",
            "dashboard.log_symptoms": "Записать симптомы",
            "dashboard.loading": "Обновляем воздух вокруг вас…",
            "dashboard.get_started.title": "С чего начать",
            "dashboard.get_started.hide": "Скрыть",
            "dashboard.get_started.item.risk": "Посмотрите текущий уровень риска",
            "dashboard.get_started.item.hourly": "Откройте прогноз по часам",
            "dashboard.get_started.item.recommendations": "Прочитайте рекомендации",
            "dashboard.get_started.item.profile": "Настройте профиль",
            "dashboard.get_started.item.notifications": "Включите уведомления",
            "dashboard.air_metrics": "Показатели воздуха",
            "dashboard.section.ai_summary": "Что важно сейчас",
            "dashboard.section.todays_air": "Воздух сегодня",
            "dashboard.section.todays_health": "Здоровье сегодня",
            "dashboard.hazards.title": "Опасности среды",
            "dashboard.hazards.empty": "Пока нет оценок опасностей.",
            "dashboard.hazards.unavailable": "—",
            "hazard.type.heat": "Жара",
            "hazard.type.air": "Воздух",
            "hazard.type.uv": "UV",
            "hazard.type.pollen": "Пыльца",
            "hazard.type.smoke": "Дым",
            "hazard.type.dust": "Пыль",
            "hazard.level.low": "низкий",
            "hazard.level.moderate": "умеренный",
            "hazard.level.high": "высокий",
            "hazard.level.very_high": "очень высокий",
            "hazard.level.unavailable": "нет данных",
            "settings.places.title": "Сохранённые места",
            "settings.places.empty": "Пока нет сохранённых мест.",
            "settings.places.coords": "%.4f, %.4f",
            "settings.places.delete": "Удалить",
            "settings.places.add_home": "Добавить текущий дом",
            "settings.places.home_default_name": "Дом",
            "settings.places.added": "Место сохранено",
            "settings.places.add_failed": "Не удалось сохранить место",
            "settings.places.deleted": "Место удалено",
            "settings.places.delete_failed": "Не удалось удалить место",
            "settings.places.load_failed": "Не удалось загрузить места",
            "insights.adaptation.title": "Адаптация и защищённые дни",
            "insights.adaptation.baselines.empty": "Базовые показатели пока недоступны.",
            "insights.adaptation.baseline_line": "%@ (%@): %.0f",
            "insights.adaptation.protected_days": "Избежано рискованных периодов: %d · Перенесено тренировок: %d · Окон проветривания: %d · Снижено воздействие плохого воздуха: %d",
            "insights.adaptation.metric.resting_heart_rate": "Пульс в покое",
            "insights.adaptation.metric.hrv": "HRV",
            "insights.adaptation.metric.sleep_minutes": "Сон (мин)",
            "insights.adaptation.metric.steps": "Шаги",
            "insights.adaptation.metric.exercise_minutes": "Активность (мин)",
            "insights.adaptation.window.d7": "7 дней",
            "insights.adaptation.window.d30": "30 дней",
            "dashboard.section.quick_actions": "Что сделать",
            "insights.window.hint": "Неделя — быстрый обзор. Месяц — более устойчивые закономерности.",
            "symptoms.repeat": "Повторить",
            "paywall.compare.title": "Free и Premium",
            "paywall.compare.badge.free": "Free",
            "paywall.compare.badge.premium": "Premium",
            "paywall.compare.free.risk": "Текущий риск и воздух",
            "paywall.compare.free.health": "Сводка здоровья и журнал симптомов",
            "paywall.compare.premium.planner": "Почасовой план дня",
            "paywall.compare.premium.insights": "Тренды и связи 7/30 дней",
            "paywall.compare.premium.ai": "Живые AI-объяснения с health context",
            "paywall.compare.premium.reports": "Вечерний и недельный AI-отчёт",
            "paywall.examples.title": "Что вы увидите",
            "paywall.examples.ai.title": "Пример AI",
            "paywall.examples.ai.body": "«Сегодня воздух умеренный. Короткий выход на улицу утром будет комфортнее, чем днём.»",
            "paywall.examples.insights.title": "Пример инсайта",
            "paywall.examples.insights.body": "«В дни с более коротким сном симптомы отмечались чаще. Это наблюдение, не причина.»",
            "paywall.examples.forecast.title": "Пример прогноза",
            "paywall.examples.forecast.body": "Безопасные окна прогулки и вентиляции на ближайшие часы.",
            "common.info": "Подробнее",
            "dashboard.source_live": "Данные в реальном времени",
            "dashboard.source_cached": "Кэшированные данные",
            "dashboard.source_sample": "Оценка по ближайшим данным",
            "dashboard.metric.aqi": "AQI",
            "dashboard.metric.pm25": "PM2.5",
            "dashboard.metric.ozone": "Озон",
            "dashboard.metric.heat_index": "Heat Index",
            "dashboard.metric.humidity": "Влажность",
            "dashboard.tooltip.risk_score": "Общая оценка риска для вас на основе жары, влажности и качества воздуха.",
            "dashboard.tooltip.aqi": "Индекс качества воздуха. Чем выше значение, тем хуже воздух.",
            "dashboard.tooltip.pm25": "Мелкие частицы загрязнения воздуха, которые могут раздражать лёгкие.",
            "dashboard.tooltip.ozone": "Озон у земли может ухудшать дыхание, особенно в жаркие дни.",
            "dashboard.tooltip.heat_index": "Ощущаемая температура с учётом влажности.",
            "dashboard.tooltip.humidity": "Влажность воздуха. Высокая влажность усиливает ощущение жары.",
            "planner.title": "План дня",
            "planner.subtitle": "Полный план на основе профиля и качества воздуха.",
            "planner.safe_windows": "Безопасные окна",
            "planner.ventilation_windows": "Окна проветривания",
            "planner.hourly_risk": "Риск по часам",
            "planner.hourly": "Почасово",
            "planner.refresh": "Обновить план",
            "planner.apply": "Применить план",
            "planner.loading": "Составляем план дня…",
            "planner.profile_required": "Сначала войдите и создайте профиль.",
            "planner.fetch": "Загрузите план дня, чтобы увидеть ключевой интервал.",
            "planner.failed": "Не удалось загрузить план.",
            "planner.empty.no_profile.title": "Профиль пока не настроен",
            "planner.empty.no_profile.body": "Без профиля HiAir не может рассчитать персональные безопасные окна.",
            "planner.empty.no_profile.cta": "Создать профиль автоматически",
            "planner.empty.unavailable.title": "Прогноз временно недоступен",
            "planner.empty.unavailable.body": "Проверьте интернет или попробуйте снова через минуту.",
            "planner.loaded": "Загружено %d почасовых слотов.",
            "planner.forecast_partial": "Прогноз частично доступен — часть метрик отсутствует.",
            "planner.forecast_unavailable": "Почасовой прогноз сейчас недоступен.",
            "planner.freshness.live": "Прогноз обновлён",
            "planner.freshness.cached": "Показан кэшированный прогноз",
            "planner.freshness.stale": "Прогноз устарел — обновляем при возможности",
            "planner.sources": "Источник",
            "dashboard.metric.unavailable": "Нет данных",
            "planner.legend.low": "Низкий",
            "planner.legend.moderate": "Средний",
            "planner.legend.high": "Высокий",
            "planner.window.safe": "Безопасно",
            "planner.window.ventilation": "Проветрить",
            "planner.peak": "Пик: %@ в %@",
            "planner.peak_line": "Пик %@ в %@",
            "planner.activity.title": "Лучшее время для активности",
            "planner.activity.subtitle": "Выберите активность — HiAir подскажет лучшие, приемлемые и нежелательные окна.",
            "planner.activity.picker": "Активность",
            "planner.activity.place": "Место",
            "planner.activity.place_home": "Домашняя точка",
            "planner.activity.mark_planned": "Отметить перенос тренировки",
            "planner.activity.mark_planned_done": "Сохранено в защищённые дни",
            "planner.activity.mark_planned_failed": "Не удалось сохранить",
            "planner.ventilation.mark_used": "Отметить проветривание",
            "planner.ventilation.mark_done": "Проветривание сохранено в защищённые дни",
            "settings.work.title": "Рабочая безопасность",
            "settings.work.subtitle": "Оценка теплового стресса на площадке (не мед. совет)",
            "settings.work.workload": "Нагрузка",
            "settings.work.workload.light": "Лёгкая",
            "settings.work.workload.moderate": "Умеренная",
            "settings.work.workload.heavy": "Тяжёлая",
            "settings.work.workload.very_heavy": "Очень тяжёлая",
            "settings.work.refresh": "Проверить площадку",
            "settings.work.summary": "Риск: %@ · %@",
            "settings.work.work_rest": "Работа %d мин / отдых %d мин",
            "settings.work.proxy_disclaimer": "WBGT недоступен — осторожная оценка по heat index, не WBGT",
            "settings.work.no_location": "Укажите координаты профиля",
            "settings.work.load_failed": "Не удалось загрузить оценку площадки",
            "settings.family.title": "Семья",
            "settings.family.subtitle": "Свяжите профили близких для совместного мониторинга",
            "settings.family.empty": "Пока нет связанных профилей",
            "settings.family.add": "Добавить",
            "settings.family.delete": "Удалить",
            "settings.family.added": "Профиль добавлен в семью",
            "settings.family.deleted": "Связь удалена",
            "settings.family.add_failed": "Не удалось добавить профиль",
            "settings.family.delete_failed": "Не удалось удалить связь",
            "settings.family.load_failed": "Не удалось загрузить семью",
            "settings.family.relation.child": "Ребёнок",
            "settings.family.relation.spouse": "Партнёр",
            "settings.family.relation.parent": "Родитель",
            "settings.family.relation.other": "Другое",
            "settings.family.relation.partner": "Партнёр",
            "settings.family.relation.elderly": "Пожилой родственник",
            "settings.family.risk_line": "Риск: %@ (%d)",
            "settings.family.risk_unavailable": "Риск недоступен",
            "dashboard.protected.title": "Защищённый день",
            "dashboard.family.title": "Риск семьи",
            "dashboard.family.highest": "Максимальный риск:",
            "dashboard.protected.subtitle": "Отметьте, что вы снизили воздействие (ассоциация, не причинность)",
            "dashboard.protected.exposure": "Снизил(а) воздействие плохого воздуха",
            "dashboard.protected.risk_avoided": "Избежал(а) периода высокого риска",
            "dashboard.protected.exposure_done": "Отмечено: снижение воздействия",
            "dashboard.protected.risk_avoided_done": "Отмечено: избежание высокого риска",
            "planner.activity.loading": "Ищем лучшее время…",
            "planner.activity.recommended": "Рекомендуемое начало: %@",
            "planner.activity.no_windows": "Подходящих окон на сегодня нет.",
            "planner.activity.forecast_unavailable": "Прогноз для планирования активности сейчас недоступен.",
            "planner.activity.tier.best": "Лучшее",
            "planner.activity.tier.acceptable": "Приемлемо",
            "planner.activity.tier.avoid": "Избегать",
            "planner.activity.running": "Бег",
            "planner.activity.walking": "Прогулка",
            "planner.activity.cycling": "Велосипед",
            "planner.activity.hiking": "Поход",
            "planner.activity.dog_walk": "Выгул собаки",
            "planner.activity.playground": "Детская площадка",
            "planner.activity.outdoor_sport": "Спорт на улице",
            "planner.activity.beach": "Пляж",
            "planner.activity.outdoor_work": "Работа на улице",
            "planner.activity.ventilation": "Проветривание",
            "planner.activity.reason.aqi": "AQI",
            "planner.activity.reason.pm25": "PM2.5",
            "planner.activity.reason.ozone": "Озон",
            "planner.activity.reason.air": "Качество воздуха",
            "planner.activity.reason.heat": "Жара",
            "planner.activity.reason.uv": "UV",
            "planner.activity.reason.uv_unavailable": "UV недоступен",
            "planner.activity.reason.air_data_unavailable": "Нет данных о воздухе",
            "planner.activity.reason.personal_load": "Личная нагрузка",
            "planner.activity.reason.child_caution": "Осторожность для детей",
            "planner.activity.reason.low_heat": "Низкая жара",
            "planner.activity.reason.good_air": "Хороший воздух",
            "common.unavailable": "Нет данных",
            "symptoms.title": "Журнал симптомов",
            "symptoms.subtitle": "Отмечайте самочувствие для точных персональных рекомендаций.",
            "symptoms.streak": "Ведите журнал, чтобы видеть паттерны",
            "symptoms.profile_id": "Profile ID",
            "symptoms.cough": "Кашель",
            "symptoms.wheeze": "Свистящее дыхание",
            "symptoms.headache": "Головная боль",
            "symptoms.fatigue": "Усталость",
            "symptoms.sleep_quality": "Качество сна",
            "symptoms.quick_intensity": "Интенсивность (быстро)",
            "symptoms.quick_breath": "Быстро: Дыхание",
            "symptoms.quick_headache": "Быстро: Голова",
            "symptoms.save": "Сохранить симптомы",
            "symptoms.submit": "Отправить симптомы",
            "symptoms.saving": "Сохраняем...",
            "symptoms.saved_at": "Сохранено в",
            "symptoms.save_failed": "Не удалось сохранить симптомы.",
            "symptoms.quick_saved": "Быстрый симптом сохранён.",
            "symptoms.quick_failed": "Не удалось сохранить быстрый симптом.",
            "symptoms.empty.title": "Журнал симптомов пока пуст",
            "symptoms.empty.body": "Добавьте первый симптом, чтобы HiAir точнее подбирал рекомендации.",
            "symptoms.favorites": "Частые симптомы",
            "symptoms.search": "Поиск симптома",
            "symptoms.all_categories": "Все",
            "symptoms.severity": "Интенсивность",
            "symptoms.location": "Где вы были",
            "symptoms.location.any": "Не важно",
            "symptoms.location.indoors": "В помещении",
            "symptoms.location.outdoors": "На улице",
            "symptoms.note_optional": "Заметка (необязательно)",
            "symptoms.select_first": "Сначала выберите симптом.",
            "settings.ai_observability": "AI наблюдаемость",
            "settings.subtitle": "Управляйте уведомлениями, подпиской и AI-наблюдаемостью.",
            "settings.notifications": "Уведомления",
            "settings.push": "Включить push-уведомления",
            "settings.morning_briefing": "Morning Briefing",
            "settings.morning_briefing_time": "Время брифинга (HH:MM)",
            "settings.morning_briefing_hint": "Персональная сводка каждое утро.",
            "settings.profile_alerting": "Алерты с учетом профиля",
            "settings.alert_threshold": "Порог алерта",
            "settings.threshold_medium": "Средний",
            "settings.threshold_high": "Высокий",
            "settings.threshold_very_high": "Очень высокий",
            "settings.quiet_start": "Тихие часы: начало",
            "settings.quiet_end": "Тихие часы: конец",
            "settings.profile_defaults": "Профиль по умолчанию",
            "settings.persona": "Персона",
            "settings.persona_adult": "Взрослый",
            "settings.persona_child": "Ребенок",
            "settings.persona_elderly": "Пожилой",
            "settings.persona_asthma": "Астма",
            "settings.persona_allergy": "Аллергия",
            "settings.persona_runner": "Бегун",
            "settings.persona_worker": "Рабочий на улице",
            "settings.language": "Язык",
            "settings.language_ru": "Русский",
            "settings.language_en": "English",
            "settings.language_es": "Español",
            "settings.language_it": "Italiano",
            "settings.language_fr": "Français",
            "settings.window_24h": "24ч",
            "settings.window_72h": "72ч",
            "settings.sync": "Синхронизация",
            "settings.loading": "Загружаем настройки…",
            "settings.saving": "Сохраняем...",
            "settings.subscription": "Подписка",
            "settings.upgrade_premium": "Перейти на Premium",
            "settings.premium_active": "Premium активен.",
            "settings.premium_inactive": "Premium не активен. Оформите подписку через App Store.",
            "settings.premium_until": "Premium до %@",
            "settings.premium_free": "Free",
            "settings.premium_badge": "Premium",
            "settings.profile_section": "Профиль",
            "settings.manage_subscription": "Управлять подпиской",
            "settings.restore_purchases": "Восстановить покупки",
            "settings.subscription_dev": "Разработчик: тест API",
            "paywall.nav_title": "Premium",
            "paywall.title": "HiAir Premium",
            "paywall.subtitle": "Семейные профили, расширенный прогноз и персональные инсайты.",
            "paywall.benefit.profiles": "До 6 семейных профилей",
            "paywall.benefit.forecast": "Почасовой прогноз и безопасные окна",
            "paywall.benefit.alerts": "Персональные брифинги и алерты",
            "paywall.benefit.export": "Экспорт данных",
            "paywall.benefit.insights": "Расширенные инсайты",
            "paywall.loading": "Загрузка планов…",
            "paywall.products_unavailable": "Не удалось загрузить планы подписки из App Store.",
            "paywall.products_empty": "Планы подписки временно недоступны. Проверьте App Store и повторите попытку.",
            "paywall.plan_monthly": "Premium — ежемесячно",
            "paywall.plan_yearly": "Premium — ежегодно",
            "paywall.subscribe_monthly": "Подписаться — ежемесячно",
            "paywall.subscribe_yearly": "Подписаться — ежегодно",
            "paywall.price_pending": "Цена в App Store",
            "paywall.auth_required": "Сначала войдите в аккаунт.",
            "paywall.purchasing": "Оформление покупки…",
            "paywall.restoring": "Восстановление…",
            "paywall.asc_hint": "Если ошибка повторяется, проверьте Paid Apps Agreement, Tax и Banking в App Store Connect.",
            "paywall.retry": "Повторить",
            "paywall.restore": "Восстановить покупки",
            "paywall.disclaimer": "HiAir — wellness-напоминания, не медицинский совет.",
            "paywall.terms": "Условия",
            "paywall.privacy": "Конфиденциальность",
            "paywall.success": "Premium активирован.",
            "paywall.verify_pending": "Покупка получена. Подтверждаем Premium на сервере…",
            "paywall.purchase_pending": "Покупка ожидает подтверждения. Premium откроется после одобрения Apple.",
            "paywall.purchase_cancelled": "Покупка отменена.",
            "paywall.verification_failed": "Не удалось проверить покупку. Premium не активирован.",
            "paywall.purchase_in_progress": "Покупка уже выполняется. Подождите завершения.",
            "paywall.restore_success": "Покупки восстановлены.",
            "paywall.restore_nothing": "Активных Premium-покупок для этого Apple ID не найдено.",
            "paywall.generic_error": "Не удалось завершить покупку. Попробуйте ещё раз.",
            "paywall.server_error": "Сервер временно недоступен. Попробуйте чуть позже.",
            "paywall.network_error": "Нет соединения. Проверьте интернет и повторите.",
            "settings.date_of_birth": "Дата рождения",
            "settings.age_years": "Возраст",
            "onboarding.date_of_birth.title": "Дата рождения",
            "onboarding.date_of_birth.body": "Нужна для персональных рекомендаций и аналитики риска по возрасту.",
            "common.close": "Закрыть",
            "settings.security_privacy": "Безопасность и приватность",
            "settings.plan": "План",
            "settings.status": "Статус",
            "settings.sync_now": "Сохранить настройки и синхронизировать",
            "settings.advanced_controls": "Расширенные параметры графика",
            "settings.load": "Загрузить настройки",
            "settings.save": "Сохранить настройки",
            "settings.load_plans": "Загрузить планы",
            "settings.load_subscription": "Загрузить подписку",
            "settings.activate_subscription": "Активировать подписку",
            "settings.cancel_subscription": "Отменить подписку",
            "settings.user_id_required": "Войдите в аккаунт, чтобы сохранить настройки.",
            "settings.loaded": "Настройки загружены.",
            "settings.load_failed": "Не удалось загрузить настройки.",
            "settings.saved": "Настройки сохранены.",
            "settings.save_failed": "Не удалось сохранить настройки.",
            "settings.plans_loaded": "Планы загружены.",
            "settings.plans_load_failed": "Не удалось загрузить планы.",
            "settings.subscription_loaded": "Подписка загружена.",
            "settings.subscription_load_failed": "Не удалось загрузить подписку.",
            "settings.subscription_activated": "Подписка активирована.",
            "settings.subscription_activate_failed": "Не удалось активировать подписку.",
            "settings.subscription_canceled": "Подписка отменена.",
            "settings.subscription_cancel_failed": "Не удалось отменить подписку.",
            "settings.subscription_status_active": "активна",
            "settings.subscription_status_inactive": "неактивна",
            "settings.subscription_status_canceled": "отменена",
            "settings.logged_out": "Вы вышли из аккаунта.",
            "settings.log_out": "Выйти",
            "settings.help_title": "Справка",
            "settings.help_open": "Справочник HiAir",
            "settings.ai_guide_open": "ИИ-гид",
            "settings.onboarding_reopen": "Показать онбординг снова",
            "settings.notifications_off_hint": "Уведомления выключены. Вы можете пропустить важные предупреждения о жаре и воздухе.",
            "settings.privacy_export": "Экспортировать мои данные",
            "settings.privacy_export_ready": "Секций данных",
            "settings.privacy_export_done": "Экспорт данных готов.",
            "settings.privacy_export_failed": "Не удалось экспортировать данные.",
            "settings.delete_account": "Удалить аккаунт",
            "settings.account_deleted": "Аккаунт удален.",
            "settings.account_delete_failed": "Не удалось удалить аккаунт.",
            "settings.user_id": "User ID",
            "settings.token": "Access token",
            "settings.window": "Окно",
            "settings.metric": "Метрика",
            "settings.metric.total": "Всего",
            "settings.metric.fallback": "Fallback",
            "settings.metric.guardrail": "Guardrail",
            "settings.metric.errors": "Ошибки (сумма)",
            "settings.metric.timeout": "Таймаут",
            "settings.metric.network": "Сеть",
            "settings.metric.server": "Сервер",
            "settings.mode": "Режим",
            "settings.mode.bars": "Столбцы",
            "settings.mode.line": "Линия",
            "settings.range": "Диапазон",
            "settings.axis": "Ось",
            "settings.request_status": "Статус запроса",
            "settings.request_loading": "Загрузка...",
            "settings.request_idle": "Ожидание",
            "settings.request_timeout": "Таймаут",
            "settings.last_updated": "Последнее обновление",
            "settings.ai_retry_now": "Повторить сейчас",
            "settings.ai_retry_later": "Повторить позже",
            "settings.ai_timeout_inline": "Превышено время ожидания AI запроса.",
            "settings.ai_network_inline": "Нет сети. Проверьте подключение и попробуйте снова.",
            "settings.ai_server_inline": "Сервер временно недоступен. Попробуйте позже.",
            "settings.ai_request_failed_inline": "Ошибка запроса AI наблюдаемости.",
            "settings.ai_top_prompt": "Топ версия промпта",
            "settings.ai_top_model": "Топ модель",
            "settings.ai_error_counts": "Ошибки",
            "settings.ai_error_type.timeout": "таймаут",
            "settings.ai_error_type.network": "сеть",
            "settings.ai_error_type.server": "сервер",
            "settings.ai_error_type.other": "прочее",
            "settings.ai_events": "AI события",
            "settings.ai_fallback": "fallback",
            "settings.ai_guardrail_blocks": "блокировки guardrail",
            "settings.ai_latest_hour": "Последний час",
            "settings.ai_blocks_short": "блоки",
            "settings.ai_no_trend": "Для выбранного периода нет точек тренда.",
            "settings.ai_loaded": "Загружено · %@",
            "settings.ai_failed": "Не удалось загрузить AI наблюдаемость.",
            "settings.ai_request_failed": "Запрос AI наблюдаемости завершился ошибкой.",
            "settings.load_ai_summary": "Загрузить AI сводку",
            "settings.loading_ai_metrics": "Загружаем AI метрики...",
            "guide.title": "Справочник HiAir",
            "guide.what_is_title": "Что такое HiAir",
            "guide.what_is_body": "HiAir — мобильный ассистент по жаре и качеству воздуха. Он показывает риск именно для вашего профиля.",
            "guide.problems_title": "Какие проблемы решает приложение",
            "guide.problems_body": "Помогает выбрать безопасное время для прогулки, спорта и проветривания, а также снизить риск при жаре и загрязнении воздуха.",
            "guide.for_whom_title": "Для кого HiAir полезен",
            "guide.for_whom_body": "Для взрослых, детей, пожилых людей и пользователей с астмой или аллергией, а также для тех, кто много времени проводит на улице.",
            "guide.read_dashboard_title": "Как читать главный экран",
            "guide.read_dashboard_body": "Сначала смотрите Risk Score, затем безопасные окна и рекомендации. Это три ключевых блока для решения «что делать сейчас».",
            "guide.risk_title": "Что означает Risk Score",
            "guide.risk_body": "Это общая оценка риска на основе жары, влажности и качества воздуха с учётом вашего профиля.",
            "guide.metrics_title": "Что такое AQI, PM2.5, озон, влажность и жара",
            "guide.metrics_body": "AQI показывает общий уровень загрязнения. PM2.5 — мелкие частицы. Озон у земли может ухудшать дыхание. Влажность и жара влияют на переносимость нагрузки.",
            "guide.hourly_title": "Как пользоваться прогнозом по часам",
            "guide.hourly_body": "Смотрите почасовой риск и планируйте активность на интервалы с более низким риском.",
            "guide.safe_windows_title": "Что такое безопасные окна",
            "guide.safe_windows_body": "Это интервалы, когда условия обычно лучше подходят для прогулки, спорта или проветривания.",
            "guide.symptoms_title": "Как пользоваться журналом симптомов",
            "guide.symptoms_body": "Отмечайте симптомы ежедневно. Это делает рекомендации более персональными и точными.",
            "guide.notifications_title": "Как настроить уведомления",
            "guide.notifications_body": "Включите уведомления, чтобы получать предупреждения о небезопасных условиях заранее.",
            "guide.high_risk_title": "Что делать при высоком риске",
            "guide.high_risk_body": "Снизьте нагрузку на улице, избегайте пиков жары, проветривайте в безопасные окна и следуйте рекомендациям приложения.",
            "guide.not_doctor_title": "Почему HiAir не заменяет врача",
            "guide.not_doctor_body": "HiAir помогает с повседневными решениями, но не ставит диагноз и не заменяет медицинскую помощь.",
            "guide.faq_title": "Частые вопросы",
            "guide.faq_body": "Если данные временно недоступны, попробуйте обновить экран или позже повторить запрос.",
            "ai_guide.title": "ИИ-гид HiAir",
            "ai_guide.placeholder": "Спросите, как пользоваться приложением...",
            "ai_guide.send": "Спросить",
            "ai_guide.clear": "Новый диалог",
            "ai_guide.greeting": "Привет! Я ИИ-гид HiAir. Задайте вопрос, и я дам короткий пошаговый ответ.",
            "ai_guide.subtitle": "Подскажу шаги и сразу проведу к нужному экрану",
            "ai_guide.language_hint": "Отвечаю на языке приложения:",
            "ai_guide.user_label": "Вы",
            "ai_guide.assistant_label": "HiAir Гид",
            "ai_guide.followup": "Если нужно, задайте уточняющий вопрос — разберем подробнее.",
            "ai_guide.action.open_dashboard": "Открыть Главную",
            "ai_guide.action.open_planner": "Открыть План",
            "ai_guide.action.open_insights": "Открыть Инсайты",
            "ai_guide.action.open_symptoms": "Открыть Симптомы",
            "ai_guide.action.open_notifications": "Открыть Настройки",
            "ai_guide.action.open_account": "Открыть Аккаунт",
            "ai_guide.action.open_onboarding": "Запустить онбординг",
            "ai_guide.suggestion.onboarding": "Как начать пользоваться приложением?",
            "ai_guide.suggestion.risk": "Как интерпретировать Risk, AQI и PM2.5?",
            "ai_guide.suggestion.safe_windows": "Как использовать безопасные окна?",
            "ai_guide.suggestion.notifications": "Как включить уведомления?",
            "ai_guide.suggestion.symptoms": "Как вести журнал симптомов?",
            "ai_guide.suggestion.account": "Как управлять аккаунтом и данными?",
            "ai_guide.intent.onboarding.title": "Как начать работу с HiAir:",
            "ai_guide.intent.onboarding.step1": "Войдите или зарегистрируйтесь на экране аккаунта.",
            "ai_guide.intent.onboarding.step2": "Пройдите онбординг и выберите, для кого используете HiAir.",
            "ai_guide.intent.onboarding.step3": "На главном экране посмотрите Risk Score и чек-лист «С чего начать».",
            "ai_guide.intent.onboarding.step4": "Откройте вкладку «План» и проверьте безопасные окна на сегодня.",
            "ai_guide.intent.risk.title": "Как читать показатели риска:",
            "ai_guide.intent.risk.step1": "Сначала смотрите Risk Score — это общий риск именно для вашего профиля.",
            "ai_guide.intent.risk.step2": "AQI показывает общее загрязнение воздуха: чем выше число, тем хуже условия.",
            "ai_guide.intent.risk.step3": "PM2.5 и озон показывают факторы, которые чаще всего ухудшают дыхание.",
            "ai_guide.intent.risk.step4": "При высоком риске ориентируйтесь на рекомендации и безопасные окна.",
            "ai_guide.intent.planner.title": "Как использовать прогноз и безопасные окна:",
            "ai_guide.intent.planner.step1": "Откройте вкладку «План дня».",
            "ai_guide.intent.planner.step2": "Посмотрите почасовой риск и найдите интервалы с более низким риском.",
            "ai_guide.intent.planner.step3": "Перенесите прогулку, спорт или проветривание на безопасные окна.",
            "ai_guide.intent.planner.step4": "Если условий нет, сократите активность на улице и проверьте обновление позже.",
            "ai_guide.intent.notifications.title": "Как настроить уведомления:",
            "ai_guide.intent.notifications.step1": "Откройте «Настройки -> Уведомления».",
            "ai_guide.intent.notifications.step2": "Включите push-уведомления и при необходимости «Утренний брифинг».",
            "ai_guide.intent.notifications.step3": "Выставьте порог алертов и тихие часы под ваш режим дня.",
            "ai_guide.intent.notifications.step4": "Сохраните настройки и убедитесь, что пункт чек-листа отмечен.",
            "ai_guide.intent.symptoms.title": "Как вести журнал симптомов и получать инсайты:",
            "ai_guide.intent.symptoms.step1": "Откройте вкладку «Симптомы» и добавляйте самочувствие регулярно.",
            "ai_guide.intent.symptoms.step2": "Используйте быстрые кнопки, если нет времени на полный ввод.",
            "ai_guide.intent.symptoms.step3": "После накопления данных откройте «Инсайты» для персональных паттернов.",
            "ai_guide.intent.symptoms.step4": "Сравнивайте инсайты с погодой и качеством воздуха при планировании дня.",
            "ai_guide.intent.account.title": "Как управлять аккаунтом, профилем и приватностью:",
            "ai_guide.intent.account.step1": "В разделе «Настройки» проверьте email, язык и профиль по умолчанию.",
            "ai_guide.intent.account.step2": "Для бэкапа используйте «Экспортировать мои данные».",
            "ai_guide.intent.account.step3": "При необходимости можно выйти из аккаунта или удалить его.",
            "ai_guide.intent.account.step4": "После изменений синхронизируйте настройки кнопкой внизу экрана.",
            "ai_guide.intent.fallback.title": "Универсальный план по любому вопросу:",
            "ai_guide.intent.fallback.step1": "Опишите цель: что хотите сделать в приложении.",
            "ai_guide.intent.fallback.step2": "Укажите, на каком экране вы сейчас находитесь.",
            "ai_guide.intent.fallback.step3": "Я подскажу точный путь по кнопкам и экранам шаг за шагом.",
            "ai_guide.intent.fallback.step4": "Если что-то не работает, пришлите текст ошибки — подскажу, как исправить.",
        ],
        "en": [
            "title.settings": "Settings",
            "tab.dashboard": "Dashboard",
            "tab.planner": "Planner",
            "tab.insights": "Insights",
            "insights.empty": "Log symptoms to unlock personal patterns.",
            "insights.unlock_more": "Log 5 more days to unlock patterns.",
            "insights.failed": "Failed to load insights.",
            "insights.count": "insights",
            "insights.loading": "Loading personal patterns...",
            "insights.retry": "Try again",
            "insights.progress_title": "Progress toward insights",
            "insights.next_step": "Do this now",
            "insights.next.log_symptoms": "Log symptoms today",
            "insights.next.open_planner": "Refresh daily plan",
            "insights.refresh": "Refresh insights",
            "insights.sample_size": "Based on %d observations",
            "insights.window.title": "Analysis period",
            "insights.window.7d": "7 days",
            "insights.window.30d": "30 days",
            "insights.section.today": "Today",
            "insights.section.trends": "Trends: sleep, activity, and recovery",
            "insights.section.trends.empty": "Not enough data for trends yet.",
            "insights.section.associations": "Links: environment, sleep, load, and symptoms",
            "insights.section.associations.empty": "Associations appear after several journal days.",
            "insights.section.forecast": "What to consider today",
            "insights.section.recommendations": "Recommendations from your data",
            "insights.section.insufficient": "Not enough data yet",
            "insights.section.health_status": "Health data status",
            "insights.section.premium_patterns": "Advanced patterns",
            "insights.health_status": "Metric days: %d · %@",
            "insights.health_status_unknown": "Health data not synced yet.",
            "insights.sync.ok": "sync looks good",
            "insights.sync.partial": "partial sync",
            "insights.sync.pending": "sync in progress",
            "insights.sync.error": "sync error",
            "insights.sync.unknown": "sync status unavailable",
            "insights.progress_days": "%d of %d days with data",
            "symptoms.severity.mild": "Mild",
            "symptoms.severity.moderate": "Moderate",
            "symptoms.severity.severe": "Severe",
            "symptoms.unknown": "Symptom",
            "symptoms.frequency": "Frequency",
            "symptoms.frequency.any": "Not specified",
            "symptoms.frequency.once": "Once",
            "symptoms.frequency.intermittent": "Intermittent",
            "symptoms.frequency.constant": "Constant",
            "symptoms.duration": "Duration",
            "symptoms.duration.any": "Not specified",
            "symptoms.duration.15m": "Up to 15 min",
            "symptoms.duration.1h": "About an hour",
            "symptoms.duration.3h": "Several hours",
            "symptoms.duration.day": "All day",
            "symptoms.ongoing": "Still ongoing",
            "symptoms.activity": "Activity at onset",
            "symptoms.activity.any": "Not specified",
            "symptoms.activity.rest": "Rest",
            "symptoms.activity.walk": "Walk",
            "symptoms.activity.exercise": "Exercise",
            "symptoms.activity.work": "Work",
            "symptoms.activity.sleep": "Sleep",
            "symptoms.hydration": "Hydration",
            "symptoms.hydration.any": "Not specified",
            "symptoms.hydration.low": "Low",
            "symptoms.hydration.ok": "Adequate",
            "symptoms.hydration.high": "High",
            "symptoms.medication": "Took medication",
            "symptoms.trigger_optional": "Possible trigger (optional)",
            "symptoms.taxonomy_failed": "Couldn’t load symptoms. Check your connection and try again.",
            "symptoms.headline": "How are you feeling?",
            "symptoms.loading": "Loading symptoms…",
            "symptoms.check_connection": "Check connection",
            "symptoms.recents": "Recent",
            "symptoms.categories": "Categories",
            "symptoms.history": "History",
            "symptoms.history_empty": "No entries yet — log your first symptom.",
            "symptoms.today": "Today",
            "symptoms.yesterday": "Yesterday",
            "symptoms.edit": "Edit",
            "symptoms.delete": "Delete",
            "symptoms.delete_confirm": "Delete this symptom entry?",
            "symptoms.deleted": "Entry deleted.",
            "symptoms.more_details": "More details",
            "symptoms.no_search_results": "No matches. Try another name.",
            "symptoms.cached_offline": "Showing saved list (offline).",
            "symptoms.add_custom": "Add your own symptom",
            "symptoms.custom_label": "Symptom name",
            "symptoms.custom_added": "Custom symptom added.",
            "symptoms.entry_title": "Symptom entry",
            "symptoms.onset": "When it started",
            "symptoms.clear_search": "Clear",
            "symptoms.red_flag_hint": "Important wellness signal — seek help if needed.",
            "common.cancel": "Cancel",
            "insights.today.steps": "Steps: %d",
            "insights.today.sleep": "Sleep: %d min",
            "insights.today.rhr": "Resting HR: %d",
            "insights.today.hrv": "HRV: %d ms",
            "insights.today.spo2": "SpO₂: %d%%",
            "insights.today.resp": "Breathing: %d/min",
            "insights.today.empty": "No data for today — connect Apple Health or log symptoms.",
            "insights.confidence.preliminary": "Confidence: preliminary",
            "insights.confidence.moderate": "Confidence: moderate",
            "insights.confidence.stronger": "Confidence: stronger",
            "insights.confidence.insufficient": "Confidence: insufficient data",
            "wearable.health.error.locked": "Apple Health is temporarily unavailable (device locked). We'll retry later.",
            "settings.briefing_setup_hint": "Sign in first to configure Morning Briefing.",
            "tab.symptoms": "Symptoms",
            "tab.settings": "Settings",
            "auth.title": "HiAir Account",
            "auth.subtitle": "Breathe better. Live better.",
            "brand.tagline": "Breathe better. Live better.",
            "auth.email": "Email",
            "auth.password": "Password (min 12 chars, A/a/0-9/symbol)",
            "auth.sign_up": "Sign Up",
            "auth.signing_up": "Signing up...",
            "auth.log_in": "Log In",
            "auth.sign_in_apple": "Sign in with Apple",
            "auth.sign_in_google": "Sign in with Google",
            "auth.logging_in": "Logging in...",
            "auth.enter_email": "Enter email.",
            "auth.password_short": "Password must be at least 12 characters.",
            "auth.session_expired": "Session expired. Please sign in again.",
            "auth.ok": "Authenticated.",
            "auth.email_conflict": "An account with this email already exists.",
            "auth.backend_unreachable": "Cannot reach the server. Check your internet connection and try again.",
            "auth.backend_unavailable": "Backend is temporarily unavailable. Check database connectivity.",
            "auth.confirm_email": "We sent a confirmation link to %@. Open it, then tap Log in with the same password.",
            "auth.confirm_email_short": "Confirm your email, then log in.",
            "auth.oauth_continue": "Finish sign-in in the browser, then return to HiAir.",
            "auth.cancelled": "Sign-in cancelled.",
            "auth.fail": "Auth failed.",
            "auth.server_error": "Server error (%d). Try again later.",
            "auth.oauth_not_configured": "Sign in with %@ is not configured yet. Use email and password instead.",
            "auth.rate_limited": "Too many attempts. Wait 15 minutes and try again.",
            "auth.bridge_unreachable": "Auth server is temporarily unavailable. Try again in a minute.",
            "auth.working": "Connecting to the server…",
            "auth.bad_response": "Unexpected server response. Update the app or try again later.",
            "onboarding.title": "HiAir Onboarding",
            "onboarding.persona": "Persona",
            "onboarding.sensitivity": "Sensitivity",
            "onboarding.latitude": "Latitude",
            "onboarding.longitude": "Longitude",
            "onboarding.profile_id": "Profile ID (optional)",
            "onboarding.continue": "Continue",
            "onboarding.next": "Next",
            "onboarding.back": "Back",
            "onboarding.start": "Start",
            "onboarding.step1.title": "HiAir is your heat and air-quality helper",
            "onboarding.step1.body": "HiAir helps you understand when heat and outdoor air can become unsafe specifically for you.",
            "onboarding.step2.title": "What HiAir helps you solve",
            "onboarding.problem.heat": "Heat and overheating risk",
            "onboarding.problem.pm25": "Poor air and fine particles",
            "onboarding.problem.ozone": "Ozone, smoke, and pollution",
            "onboarding.problem.sensitive": "Kids, elderly, asthma and allergy",
            "onboarding.problem.outdoor": "Sports, walks, and outdoor work",
            "onboarding.step3.title": "Who are you using HiAir for?",
            "onboarding.for_self": "For myself",
            "onboarding.for_child": "For a child",
            "onboarding.for_elderly": "For an elderly person",
            "onboarding.for_asthma": "Asthma / breathing",
            "onboarding.for_allergy": "Allergy",
            "onboarding.for_runner": "Running / sports",
            "onboarding.for_worker": "Outdoor work",
            "onboarding.step4.title": "What to check daily",
            "onboarding.look.risk": "Your air risk index shows how conditions feel for you right now",
            "onboarding.look.hourly": "Hourly forecast shows safer windows",
            "onboarding.look.recommendations": "Recommendations explain what to do",
            "onboarding.look.notifications": "Notifications warn you in advance",
            "onboarding.step5.title": "Why permissions matter",
            "onboarding.permissions.location.title": "Location",
            "onboarding.permissions.location.body": "HiAir uses your location to estimate heat and air-quality risk for your current area.",
            "onboarding.permissions.notifications.title": "Notifications",
            "onboarding.permissions.notifications.body": "Notifications help warn you early about heat or poor air.",
            "onboarding.permissions.allow": "Allow",
            "onboarding.permissions.later": "Set up later",
            "onboarding.step6.title": "All set",
            "onboarding.step6.body": "Now open your home screen and check current risk, recommendations, and safe hours for today.",
            "onboarding.open_forecast": "Open my forecast",
            "wearable.consent.title": "Connect health & activity",
            "wearable.consent.body": "HiAir better estimates your load in heat and poor air. With your permission we use steps, distance, calories, heart rate, HRV, sleep stages, SpO₂, breathing, temperature, and workouts — only as daily aggregates for wellness tips.",
            "wearable.consent.disclaimer": "HiAir provides wellness guidance, not medical diagnosis.",
            "wearable.consent.connect": "Connect",
            "wearable.consent.skip": "Skip",
            "wearable.consent.saving": "Saving connection…",
            "wearable.consent.failed": "Couldn’t save consent. Please try again.",
            "wearable.consent.retry": "Retry",
            "wearable.consent.connected": "Health connected",
            "wearable.consent.revoking": "Disconnecting health…",
            "wearable.consent.revoke_failed": "Couldn’t finish server disconnect. Please retry.",
            "wearable.dashboard.title": "Load today",
            "wearable.dashboard.steps": "Steps",
            "wearable.dashboard.hr_normal": "Heart rate: normal",
            "wearable.dashboard.hr_elevated": "Heart rate: above usual",
            "wearable.dashboard.hr_unknown": "Heart rate: limited data",
            "wearable.dashboard.hr_bpm": "Heart rate: %d bpm",
            "wearable.dashboard.hr_elevated_bpm": "Heart rate: %d bpm (above usual)",
            "wearable.dashboard.rhr_bpm": "Resting heart rate: %d bpm",
            "wearable.dashboard.load_risk": "Load risk",
            "wearable.dashboard.not_connected": "Connect health data for better heat load estimates.",
            "wearable.dashboard.denied": "Apple Health access is off.",
            "wearable.dashboard.open_settings": "Open Settings",
            "wearable.dashboard.open_health": "Open Health",
            "wearable.dashboard.health_path": "In the Health app: Profile → Privacy → Apps → HiAir → enable Steps and Heart Rate.",
            "wearable.dashboard.unavailable": "Limited health data today. Analysis uses weather and air quality.",
            "wearable.health.error.unavailable_device": "Apple Health is not available on this device.",
            "wearable.health.error.no_types": "HealthKit read types are not configured in this app build.",
            "wearable.health.error.missing_plist": "This build is missing HealthKit privacy strings. Install a newer TestFlight build.",
            "wearable.health.error.missing_entitlement": "This build was signed without HealthKit. Enable HealthKit for com.hiair.app in Apple Developer, then rebuild TestFlight.",
            "wearable.health.error.denied": "Apple Health denied access. Open the Health app and enable data for HiAir.",
            "wearable.health.error.generic": "Apple Health error: %@",
            "wearable.health.build_label": "iOS build %@",
            "wearable.load.none": "no data",
            "wearable.load.low": "low",
            "wearable.load.moderate": "moderate",
            "wearable.load.elevated": "elevated",
            "settings.wearables.title": "Health & activity",
            "settings.wearables.status": "Apple Health",
            "settings.wearables.connect": "Connect Apple Health",
            "health.today.title": "Today’s health metrics",
            "health.today.empty": "Data is still syncing. Check back after a walk or a night’s sleep.",
            "health.today.sleep_stages": "Sleep stages",
            "health.sleep.total": "Total sleep",
            "health.sleep.deep": "Deep sleep",
            "health.sleep.rem": "REM",
            "health.sleep.core": "Light sleep",
            "health.sleep.awake": "Awake",
            "health.sleep.in_bed": "In bed",
            "health.unit.min": "min",
            "health.unit.km": "km",
            "health.unit.kcal": "kcal",
            "health.unit.bpm": "bpm",
            "health.unit.ms": "ms",
            "health.unit.celsius": "°C",
            "health.metric.steps": "Steps",
            "health.metric.distance_walking_running": "Distance",
            "health.metric.active_energy": "Active calories",
            "health.metric.exercise_minutes": "Exercise minutes",
            "health.metric.stand_minutes": "Stand minutes",
            "health.metric.flights_climbed": "Flights climbed",
            "health.metric.workout_count": "Workouts",
            "health.metric.workout_duration": "Workout time",
            "health.metric.heart_rate": "Heart rate",
            "health.metric.resting_heart_rate": "Resting heart rate",
            "health.metric.walking_heart_rate_avg": "Walking heart rate",
            "health.metric.basal_energy": "Basal energy",
            "health.metric.walking_speed": "Walking speed",
            "health.metric.walking_step_length": "Step length",
            "health.metric.walking_asymmetry": "Walking asymmetry",
            "health.metric.walking_double_support": "Double support",
            "health.metric.mindfulness_minutes": "Mindfulness",
            "health.metric.hrv_sdnn": "Heart-rate variability",
            "health.metric.respiratory_rate": "Breathing rate",
            "health.metric.oxygen_saturation": "Blood oxygen",
            "health.metric.body_temperature": "Body temperature",
            "health.metric.wrist_temperature": "Wrist temperature",
            "health.metric.vo2_max": "VO₂ max",
            "insights.premium_locked.title": "Personal analytics need Premium",
            "insights.premium_locked.body": "Unlock health trends, possible air associations, and clear recommendations for what to do today.",
            "insights.premium_locked.cta": "See Premium",
            "insights.today.distance": "Distance: %.1f km",
            "insights.today.energy": "Calories: %d",
            "insights.today.vo2": "VO₂ max: %d",
            "insights.today.workouts": "Workouts: %d",
            "planner.premium_required": "The hourly day plan is a Premium feature — safe windows and ventilation for the full day.",
            "planner.premium_locked.title": "Day plan needs Premium",
            "paywall.catalog_help": "Subscription plans are temporarily unavailable from the App Store. Check your connection and try again shortly.",
            "settings.wearables.connected": "connected",
            "settings.wearables.device_authorized": "access allowed",
            "settings.wearables.consent_inactive": "consent inactive",
            "settings.wearables.denied": "access denied",
            "settings.wearables.disconnect": "Disconnect",
            "settings.wearables.delete": "Delete health data",
            "settings.wearables.delete_done": "Local health data deleted",
            "settings.wearables.delete_confirm": "Delete all stored health summaries?",
            "common.loading": "Loading…",
            "common.retry": "Try again",
            "common.error.title": "Couldn’t load",
            "common.error.network": "Check your connection and try again.",
            "state.empty.title": "No data yet",
            "state.empty.body": "When data arrives, HiAir will show a clear result and next step.",
            "state.empty.insights.title": "Not enough logs for insights",
            "state.empty.insights.body": "Log symptoms for a few more days so HiAir can find personal patterns.",
            "state.loading": "Loading…",
            "status.excellent": "Excellent",
            "status.good": "Good",
            "status.moderate": "Moderate",
            "status.bad": "Poor",
            "dashboard.title": "Daily Air Intelligence",
            "dashboard.subtitle": "Live risk, alerts and AI insights in one place.",
            "dashboard.greeting": "Your air today",
            "dashboard.greeting_neutral": "Your air today",
            "dashboard.improving": "Personal guidance based on current conditions.",
            "dashboard.improving_neutral": "Personal guidance based on current conditions.",
            "dashboard.current_risk": "Current risk",
            "dashboard.current_risk_title": "Current risk",
            "dashboard.badge_moderate": "MODERATE",
            "dashboard.reason_unavailable": "Explanation is not available yet.",
            "dashboard.location": "Your area",
            "dashboard.location_unknown": "Location not set",
            "dashboard.weather_title": "Today's conditions",
            "dashboard.weather_unavailable": "Weather data unavailable",
            "dashboard.freshness_fresh": "Updated",
            "dashboard.freshness_stale": "Refresh",
            "dashboard.freshness_updating": "Updating…",
            "dashboard.source_estimated": "Estimated from nearby data",
            "dashboard.profile_button": "Profile",
            "dashboard.no_safe_window": "No safe windows in the next hours.",
            "dashboard.no_safe_windows": "No safe windows in the next hours.",
            "dashboard.error": "Unable to load data.",
            "dashboard.empty.no_profile.title": "Profile is not set",
            "dashboard.empty.no_profile.body": "Without profile HiAir cannot calculate personalized risk and safe windows.",
            "dashboard.empty.no_profile.cta": "Create profile automatically",
            "profile.ensure.creating": "Creating profile…",
            "profile.ensure.needs_location": "Location is required to create a profile. Allow access or refresh your place.",
            "profile.ensure.failed": "Could not create a profile. Check your connection and try again.",
            "profile.ensure.decode": "The server response could not be read. Update the app or try again later.",
            "profile.ensure.transport": "Could not reach the server. Check your network and retry.",
            "profile.ensure.cancelled": "Profile creation was interrupted. Tap again.",
            "profile.ensure.unavailable": "Service is temporarily unavailable. Try again in a minute.",
            "profile.ensure.offline": "You are offline. Check your internet connection and retry.",
            "profile.ensure.forbidden": "Profile access was denied. Sign in again or contact support.",
            "profile.ensure.premium_required": "Profile limit reached. Upgrade to Premium to add another profile.",
            "profile.ensure.retry": "Retry",
            "auth.sign_in": "Sign in",
            "dashboard.empty.api_unavailable": "Data is temporarily unavailable. Check your connection and retry.",
            "dashboard.empty.location_missing": "Location access is off. Enable it in Settings or try again.",
            "location.denied.title": "Location access is off",
            "location.denied.body": "HiAir uses your location to estimate heat and air-quality risk for your current area.",
            "location.open_settings": "Open Settings",
            "location.retry": "Retry",
            "location.services_disabled": "Location services are disabled on this device.",
            "location.timeout": "Could not determine your location. Please try again.",
            "dashboard.recommended_actions": "Recommended actions",
            "dashboard.no_actions": "No actions available.",
            "dashboard.safe_window": "Safe window",
            "dashboard.safe_windows": "Safe windows",
            "dashboard.safe_windows_tooltip": "A part of the day when conditions are safer for walks, sports, or ventilation.",
            "dashboard.auto_updates": "Auto-updates by forecast",
            "dashboard.mood_prefix": "Mood",
            "dashboard.mood.calm": "Calm",
            "dashboard.mood.aware": "Aware",
            "dashboard.mood.cautious": "Cautious",
            "dashboard.mood.protective": "Protective",
            "dashboard.do_now": "Do this now",
            "dashboard.recommendations_tooltip": "Personalized advice based on your current risk and profile.",
            "dashboard.recompute": "Recompute risk now",
            "dashboard.log_symptoms": "Log symptoms now",
            "dashboard.loading": "Updating air conditions…",
            "dashboard.get_started.title": "How to start",
            "dashboard.get_started.hide": "Hide",
            "dashboard.get_started.item.risk": "Check current risk level",
            "dashboard.get_started.item.hourly": "Open hourly forecast",
            "dashboard.get_started.item.recommendations": "Read recommendations",
            "dashboard.get_started.item.profile": "Set up your profile",
            "dashboard.get_started.item.notifications": "Turn on notifications",
            "dashboard.air_metrics": "Air metrics",
            "dashboard.section.ai_summary": "What matters now",
            "dashboard.section.todays_air": "Today's air",
            "dashboard.section.todays_health": "Today's health",
            "dashboard.hazards.title": "Environmental hazards",
            "dashboard.hazards.empty": "No hazard assessments yet.",
            "dashboard.hazards.unavailable": "—",
            "hazard.type.heat": "Heat",
            "hazard.type.air": "Air",
            "hazard.type.uv": "UV",
            "hazard.type.pollen": "Pollen",
            "hazard.type.smoke": "Smoke",
            "hazard.type.dust": "Dust",
            "hazard.level.low": "low",
            "hazard.level.moderate": "moderate",
            "hazard.level.high": "high",
            "hazard.level.very_high": "very high",
            "hazard.level.unavailable": "unavailable",
            "settings.places.title": "Saved places",
            "settings.places.empty": "No saved places yet.",
            "settings.places.coords": "%.4f, %.4f",
            "settings.places.delete": "Delete",
            "settings.places.add_home": "Add current home",
            "settings.places.home_default_name": "Home",
            "settings.places.added": "Place saved",
            "settings.places.add_failed": "Could not save place",
            "settings.places.deleted": "Place deleted",
            "settings.places.delete_failed": "Could not delete place",
            "settings.places.load_failed": "Could not load places",
            "insights.adaptation.title": "Adaptation & protected days",
            "insights.adaptation.baselines.empty": "Personal baselines are not available yet.",
            "insights.adaptation.baseline_line": "%@ (%@): %.0f",
            "insights.adaptation.protected_days": "High-risk periods avoided: %d · Workouts moved: %d · Ventilation windows: %d · Poor-air exposure reduced: %d",
            "insights.adaptation.metric.resting_heart_rate": "Resting heart rate",
            "insights.adaptation.metric.hrv": "HRV",
            "insights.adaptation.metric.sleep_minutes": "Sleep (min)",
            "insights.adaptation.metric.steps": "Steps",
            "insights.adaptation.metric.exercise_minutes": "Exercise (min)",
            "insights.adaptation.window.d7": "7 days",
            "insights.adaptation.window.d30": "30 days",
            "dashboard.section.quick_actions": "Do this next",
            "insights.window.hint": "Week for a quick view. Month for steadier patterns.",
            "symptoms.repeat": "Repeat",
            "paywall.compare.title": "Free vs Premium",
            "paywall.compare.badge.free": "Free",
            "paywall.compare.badge.premium": "Premium",
            "paywall.compare.free.risk": "Live risk and air metrics",
            "paywall.compare.free.health": "Health summary and symptom journal",
            "paywall.compare.premium.planner": "Hourly day planner",
            "paywall.compare.premium.insights": "7/30-day trends and associations",
            "paywall.compare.premium.ai": "Live AI explanations with health context",
            "paywall.compare.premium.reports": "Evening and weekly AI reports",
            "paywall.examples.title": "What you unlock",
            "paywall.examples.ai.title": "AI example",
            "paywall.examples.ai.body": "“Air is moderate today. A shorter outdoor walk this morning will feel better than midday.”",
            "paywall.examples.insights.title": "Insight example",
            "paywall.examples.insights.body": "“On shorter-sleep days, symptoms were logged more often. This is an observation, not a cause.”",
            "paywall.examples.forecast.title": "Forecast example",
            "paywall.examples.forecast.body": "Safer outdoor and ventilation windows for the next hours.",
            "common.info": "More info",
            "dashboard.source_live": "Live conditions",
            "dashboard.source_cached": "Cached conditions",
            "dashboard.source_sample": "Estimated from nearby data",
            "dashboard.metric.aqi": "AQI",
            "dashboard.metric.pm25": "PM2.5",
            "dashboard.metric.ozone": "Ozone",
            "dashboard.metric.heat_index": "Heat Index",
            "dashboard.metric.humidity": "Humidity",
            "dashboard.tooltip.risk_score": "Overall risk estimate for you based on heat, humidity, and air quality.",
            "dashboard.tooltip.aqi": "Air Quality Index. The higher the number, the worse the air.",
            "dashboard.tooltip.pm25": "Fine pollution particles that can irritate your lungs.",
            "dashboard.tooltip.ozone": "Ground-level ozone can worsen breathing, especially on hot days.",
            "dashboard.tooltip.heat_index": "How hot it feels when humidity is included.",
            "dashboard.tooltip.humidity": "Air humidity. High humidity makes heat feel stronger.",
            "planner.title": "Daily Planner",
            "planner.subtitle": "Complete recommendations based on your profile and air trends.",
            "planner.safe_windows": "Safe windows",
            "planner.ventilation_windows": "Ventilation windows",
            "planner.hourly_risk": "Hourly risk",
            "planner.hourly": "Hour-by-hour",
            "planner.refresh": "Refresh planner",
            "planner.apply": "Apply this plan",
            "planner.loading": "Building your day plan…",
            "planner.profile_required": "Sign in and create a profile first.",
            "planner.fetch": "Load daily plan to see the key interval.",
            "planner.failed": "Failed to load planner.",
            "planner.empty.no_profile.title": "Profile is not set yet",
            "planner.empty.no_profile.body": "HiAir needs your profile to calculate personalized safe windows.",
            "planner.empty.no_profile.cta": "Create profile automatically",
            "planner.empty.unavailable.title": "Forecast is temporarily unavailable",
            "planner.empty.unavailable.body": "Check your connection and try again in a minute.",
            "planner.loaded": "Loaded %d hourly slots.",
            "planner.forecast_partial": "Forecast is partially available — some metrics are missing.",
            "planner.forecast_unavailable": "Hourly forecast is unavailable right now.",
            "planner.freshness.live": "Forecast updated",
            "planner.freshness.cached": "Showing a cached forecast",
            "planner.freshness.stale": "Forecast is stale — we will refresh when possible",
            "planner.sources": "Source",
            "dashboard.metric.unavailable": "Unavailable",
            "planner.legend.low": "Low",
            "planner.legend.moderate": "Medium",
            "planner.legend.high": "High",
            "planner.window.safe": "Safe",
            "planner.window.ventilation": "Ventilate",
            "planner.peak": "Peak: %@ at %@",
            "planner.peak_line": "Peak %@ at %@",
            "planner.activity.title": "Best time for activity",
            "planner.activity.subtitle": "Pick an activity — HiAir shows best, acceptable, and avoid windows.",
            "planner.activity.picker": "Activity",
            "planner.activity.place": "Place",
            "planner.activity.place_home": "Home location",
            "planner.activity.mark_planned": "Mark workout moved",
            "planner.activity.mark_planned_done": "Saved to protected days",
            "planner.activity.mark_planned_failed": "Could not save",
            "planner.ventilation.mark_used": "Mark ventilation used",
            "planner.ventilation.mark_done": "Ventilation saved to protected days",
            "settings.work.title": "Work site safety",
            "settings.work.subtitle": "Occupational heat stress check (not medical advice)",
            "settings.work.workload": "Workload",
            "settings.work.workload.light": "Light",
            "settings.work.workload.moderate": "Moderate",
            "settings.work.workload.heavy": "Heavy",
            "settings.work.workload.very_heavy": "Very heavy",
            "settings.work.refresh": "Check site",
            "settings.work.summary": "Risk: %@ · %@",
            "settings.work.work_rest": "Work %d min / rest %d min",
            "settings.work.proxy_disclaimer": "WBGT unavailable — heat index proxy only, not WBGT",
            "settings.work.no_location": "Set profile coordinates first",
            "settings.work.load_failed": "Could not load site assessment",
            "settings.family.title": "Family",
            "settings.family.subtitle": "Link loved ones' profiles for shared monitoring",
            "settings.family.empty": "No linked profiles yet",
            "settings.family.add": "Add",
            "settings.family.delete": "Remove",
            "settings.family.added": "Profile linked to family",
            "settings.family.deleted": "Link removed",
            "settings.family.add_failed": "Could not add profile",
            "settings.family.delete_failed": "Could not remove link",
            "settings.family.load_failed": "Could not load family",
            "settings.family.relation.child": "Child",
            "settings.family.relation.spouse": "Partner",
            "settings.family.relation.parent": "Parent",
            "settings.family.relation.other": "Other",
            "settings.family.relation.partner": "Partner",
            "settings.family.relation.elderly": "Elderly relative",
            "settings.family.risk_line": "Risk: %@ (%d)",
            "settings.family.risk_unavailable": "Risk unavailable",
            "dashboard.protected.title": "Protected day",
            "dashboard.family.title": "Family risk",
            "dashboard.family.highest": "Highest risk:",
            "dashboard.protected.subtitle": "Mark steps you took to reduce exposure (association, not causation)",
            "dashboard.protected.exposure": "Reduced poor-air exposure",
            "dashboard.protected.risk_avoided": "Avoided high-risk period",
            "dashboard.protected.exposure_done": "Marked: exposure reduced",
            "dashboard.protected.risk_avoided_done": "Marked: high risk avoided",
            "planner.activity.loading": "Finding best times…",
            "planner.activity.recommended": "Recommended start: %@",
            "planner.activity.no_windows": "No suitable windows today.",
            "planner.activity.forecast_unavailable": "Activity planning forecast is unavailable right now.",
            "planner.activity.tier.best": "Best",
            "planner.activity.tier.acceptable": "Acceptable",
            "planner.activity.tier.avoid": "Avoid",
            "planner.activity.running": "Running",
            "planner.activity.walking": "Walking",
            "planner.activity.cycling": "Cycling",
            "planner.activity.hiking": "Hiking",
            "planner.activity.dog_walk": "Dog walk",
            "planner.activity.playground": "Playground",
            "planner.activity.outdoor_sport": "Outdoor sport",
            "planner.activity.beach": "Beach",
            "planner.activity.outdoor_work": "Outdoor work",
            "planner.activity.ventilation": "Ventilation",
            "planner.activity.reason.aqi": "AQI",
            "planner.activity.reason.pm25": "PM2.5",
            "planner.activity.reason.ozone": "Ozone",
            "planner.activity.reason.air": "Air quality",
            "planner.activity.reason.heat": "Heat",
            "planner.activity.reason.uv": "UV",
            "planner.activity.reason.uv_unavailable": "UV unavailable",
            "planner.activity.reason.air_data_unavailable": "Air data unavailable",
            "planner.activity.reason.personal_load": "Personal load",
            "planner.activity.reason.child_caution": "Child caution",
            "planner.activity.reason.low_heat": "Low heat",
            "planner.activity.reason.good_air": "Good air",
            "common.unavailable": "Unavailable",
            "symptoms.title": "Symptoms Log",
            "symptoms.subtitle": "Track how you feel for better personalized guidance.",
            "symptoms.streak": "Keep logging to unlock personal patterns",
            "symptoms.profile_id": "Profile ID",
            "symptoms.cough": "Cough",
            "symptoms.wheeze": "Wheeze",
            "symptoms.headache": "Headache",
            "symptoms.fatigue": "Fatigue",
            "symptoms.sleep_quality": "Sleep quality",
            "symptoms.quick_intensity": "Quick intensity",
            "symptoms.quick_breath": "Quick: Breath",
            "symptoms.quick_headache": "Quick: Headache",
            "symptoms.save": "Save Symptoms",
            "symptoms.submit": "Submit symptoms",
            "symptoms.saving": "Saving...",
            "symptoms.saved_at": "Saved at",
            "symptoms.save_failed": "Failed to save symptoms.",
            "symptoms.quick_saved": "Quick symptom saved.",
            "symptoms.quick_failed": "Failed to save quick symptom.",
            "symptoms.empty.title": "Symptoms log is empty",
            "symptoms.empty.body": "Add your first symptom to make HiAir recommendations more precise.",
            "symptoms.favorites": "Frequent symptoms",
            "symptoms.search": "Search symptom",
            "symptoms.all_categories": "All",
            "symptoms.severity": "Severity",
            "symptoms.location": "Where you were",
            "symptoms.location.any": "Any",
            "symptoms.location.indoors": "Indoors",
            "symptoms.location.outdoors": "Outdoors",
            "symptoms.note_optional": "Note (optional)",
            "symptoms.select_first": "Select a symptom first.",
            "settings.ai_observability": "AI Observability",
            "settings.subtitle": "Manage notifications, subscriptions and AI observability.",
            "settings.notifications": "Notifications",
            "settings.push": "Enable push alerts",
            "settings.morning_briefing": "Morning Briefing",
            "settings.morning_briefing_time": "Briefing time (HH:MM)",
            "settings.morning_briefing_hint": "Personal summary delivered every morning.",
            "settings.profile_alerting": "Profile-based alerting",
            "settings.alert_threshold": "Alert threshold",
            "settings.threshold_medium": "Medium",
            "settings.threshold_high": "High",
            "settings.threshold_very_high": "Very high",
            "settings.quiet_start": "Quiet start",
            "settings.quiet_end": "Quiet end",
            "settings.profile_defaults": "Profile defaults",
            "settings.persona": "Persona",
            "settings.persona_adult": "Adult",
            "settings.persona_child": "Child",
            "settings.persona_elderly": "Elderly",
            "settings.persona_asthma": "Asthma",
            "settings.persona_allergy": "Allergy",
            "settings.persona_runner": "Runner",
            "settings.persona_worker": "Outdoor worker",
            "settings.language": "Language",
            "settings.language_ru": "Russian",
            "settings.language_en": "English",
            "settings.language_es": "Spanish",
            "settings.language_it": "Italian",
            "settings.language_fr": "French",
            "settings.window_24h": "24h",
            "settings.window_72h": "72h",
            "settings.sync": "Your preferences",
            "settings.loading": "Loading settings…",
            "settings.saving": "Saving...",
            "settings.subscription": "Subscription",
            "settings.upgrade_premium": "Upgrade to Premium",
            "settings.premium_active": "Premium is active.",
            "settings.premium_inactive": "Premium is not active. Subscribe via the App Store.",
            "settings.premium_until": "Premium until %@",
            "settings.premium_free": "Free",
            "settings.premium_badge": "Premium",
            "settings.profile_section": "Profile",
            "settings.manage_subscription": "Manage subscription",
            "settings.restore_purchases": "Restore purchases",
            "settings.subscription_dev": "Developer: API testing",
            "paywall.nav_title": "Premium",
            "paywall.title": "HiAir Premium",
            "paywall.subtitle": "Family profiles, extended forecast, and advanced insights.",
            "paywall.benefit.profiles": "Up to 6 family profiles",
            "paywall.benefit.forecast": "Hourly forecast and safe windows",
            "paywall.benefit.alerts": "Custom briefings and alerts",
            "paywall.benefit.export": "Data export",
            "paywall.benefit.insights": "Advanced personal insights",
            "paywall.loading": "Loading plans…",
            "paywall.products_unavailable": "Could not load subscription plans from the App Store.",
            "paywall.products_empty": "Subscription plans are temporarily unavailable. Check the App Store and try again.",
            "paywall.plan_monthly": "Premium — monthly",
            "paywall.plan_yearly": "Premium — yearly",
            "paywall.subscribe_monthly": "Subscribe — monthly",
            "paywall.subscribe_yearly": "Subscribe — yearly",
            "paywall.price_pending": "App Store price",
            "paywall.auth_required": "Sign in to your account first.",
            "paywall.purchasing": "Processing purchase…",
            "paywall.restoring": "Restoring…",
            "paywall.asc_hint": "If this keeps failing, confirm Paid Apps Agreement, Tax, and Banking are Active in App Store Connect.",
            "paywall.retry": "Retry",
            "paywall.restore": "Restore purchases",
            "paywall.disclaimer": "HiAir provides wellness guidance, not medical advice.",
            "paywall.terms": "Terms",
            "paywall.privacy": "Privacy",
            "paywall.success": "Premium activated.",
            "paywall.verify_pending": "Purchase received. Confirming Premium on the server…",
            "paywall.purchase_pending": "Purchase is pending approval. Premium unlocks after Apple confirms.",
            "paywall.purchase_cancelled": "Purchase cancelled.",
            "paywall.verification_failed": "Purchase verification failed. Premium was not activated.",
            "paywall.purchase_in_progress": "A purchase is already in progress. Please wait.",
            "paywall.restore_success": "Purchases restored.",
            "paywall.restore_nothing": "No active Premium purchases found for this Apple ID.",
            "paywall.generic_error": "Couldn’t complete the purchase. Please try again.",
            "paywall.server_error": "Server temporarily unavailable. Try again shortly.",
            "paywall.network_error": "No connection. Check the internet and try again.",
            "settings.date_of_birth": "Date of birth",
            "settings.age_years": "Age",
            "onboarding.date_of_birth.title": "Date of birth",
            "onboarding.date_of_birth.body": "Used for age-aware health guidance and analytics.",
            "common.close": "Close",
            "settings.security_privacy": "Security & Privacy",
            "settings.plan": "Plan",
            "settings.status": "Status",
            "settings.sync_now": "Save settings & sync",
            "settings.advanced_controls": "Advanced chart controls",
            "settings.load": "Load settings",
            "settings.save": "Save settings",
            "settings.load_plans": "Load plans",
            "settings.load_subscription": "Load subscription",
            "settings.activate_subscription": "Activate subscription",
            "settings.cancel_subscription": "Cancel subscription",
            "settings.user_id_required": "Sign in to save your settings.",
            "settings.loaded": "Settings loaded.",
            "settings.load_failed": "Failed to load settings.",
            "settings.saved": "Settings saved.",
            "settings.save_failed": "Failed to save settings.",
            "settings.plans_loaded": "Plans loaded.",
            "settings.plans_load_failed": "Failed to load plans.",
            "settings.subscription_loaded": "Subscription loaded.",
            "settings.subscription_load_failed": "Failed to load subscription.",
            "settings.subscription_activated": "Subscription activated.",
            "settings.subscription_activate_failed": "Failed to activate subscription.",
            "settings.subscription_canceled": "Subscription canceled.",
            "settings.subscription_cancel_failed": "Failed to cancel subscription.",
            "settings.subscription_status_active": "active",
            "settings.subscription_status_inactive": "inactive",
            "settings.subscription_status_canceled": "canceled",
            "settings.logged_out": "Logged out.",
            "settings.log_out": "Log out",
            "settings.help_title": "Help",
            "settings.help_open": "HiAir Guide",
            "settings.ai_guide_open": "AI Assistant",
            "settings.onboarding_reopen": "Open onboarding again",
            "settings.notifications_off_hint": "Notifications are off. You may miss important heat and air alerts.",
            "settings.privacy_export": "Export my data",
            "settings.privacy_export_ready": "Data sections",
            "settings.privacy_export_done": "Data export is ready.",
            "settings.privacy_export_failed": "Failed to export data.",
            "settings.delete_account": "Delete account",
            "settings.account_deleted": "Account deleted.",
            "settings.account_delete_failed": "Failed to delete account.",
            "settings.user_id": "User ID",
            "settings.token": "Access token",
            "settings.window": "Window",
            "settings.metric": "Metric",
            "settings.metric.total": "Total",
            "settings.metric.fallback": "Fallback",
            "settings.metric.guardrail": "Guardrail",
            "settings.metric.errors": "Errors (sum)",
            "settings.metric.timeout": "Timeout",
            "settings.metric.network": "Network",
            "settings.metric.server": "Server",
            "settings.mode": "Mode",
            "settings.mode.bars": "Bars",
            "settings.mode.line": "Line",
            "settings.range": "Range",
            "settings.axis": "Axis",
            "settings.request_status": "Request status",
            "settings.request_loading": "Loading...",
            "settings.request_idle": "Idle",
            "settings.request_timeout": "Timeout",
            "settings.last_updated": "Last updated",
            "settings.ai_retry_now": "Retry now",
            "settings.ai_retry_later": "Try later",
            "settings.ai_timeout_inline": "AI observability request timed out.",
            "settings.ai_network_inline": "Network unavailable. Check your connection and retry.",
            "settings.ai_server_inline": "Server is temporarily unavailable. Please try later.",
            "settings.ai_request_failed_inline": "AI observability request failed.",
            "settings.ai_top_prompt": "Top prompt version",
            "settings.ai_top_model": "Top model",
            "settings.ai_error_counts": "Errors",
            "settings.ai_error_type.timeout": "timeout",
            "settings.ai_error_type.network": "network",
            "settings.ai_error_type.server": "server",
            "settings.ai_error_type.other": "other",
            "settings.ai_events": "AI events",
            "settings.ai_fallback": "fallback",
            "settings.ai_guardrail_blocks": "guardrail blocks",
            "settings.ai_latest_hour": "Latest hour",
            "settings.ai_blocks_short": "blocks",
            "settings.ai_no_trend": "No trend points for selected period.",
            "settings.ai_loaded": "Loaded · %@",
            "settings.ai_failed": "Failed to load AI observability.",
            "settings.ai_request_failed": "AI observability request failed.",
            "settings.load_ai_summary": "Load AI Summary",
            "settings.loading_ai_metrics": "Loading AI metrics...",
            "guide.title": "HiAir Guide",
            "guide.what_is_title": "What is HiAir",
            "guide.what_is_body": "HiAir is a mobile wellness assistant for heat and air quality. It shows risk tailored to your profile.",
            "guide.problems_title": "What problems it solves",
            "guide.problems_body": "It helps you choose safer times for walks, sports, and home ventilation, and reduce risk during heat and polluted air.",
            "guide.for_whom_title": "Who benefits from HiAir",
            "guide.for_whom_body": "Adults, children, elderly users, and people with asthma or allergy, as well as users who spend time outdoors.",
            "guide.read_dashboard_title": "How to read the home screen",
            "guide.read_dashboard_body": "Start with Risk Score, then review safe windows and recommendations. These are the three key daily blocks.",
            "guide.risk_title": "What Risk Score means",
            "guide.risk_body": "It is your overall risk estimate based on heat, humidity, and air quality, adjusted for your profile.",
            "guide.metrics_title": "What AQI, PM2.5, ozone, humidity, and heat mean",
            "guide.metrics_body": "AQI shows total pollution burden. PM2.5 are tiny particles. Ground-level ozone can irritate breathing. Humidity and heat affect comfort and stress.",
            "guide.hourly_title": "How to use hourly forecast",
            "guide.hourly_body": "Check hourly risk and plan activity for periods with lower risk.",
            "guide.safe_windows_title": "What safe windows are",
            "guide.safe_windows_body": "Time intervals when conditions are usually safer for walks, sports, or ventilation.",
            "guide.symptoms_title": "How to use symptom log",
            "guide.symptoms_body": "Track symptoms daily to make recommendations more personalized and accurate.",
            "guide.notifications_title": "How to configure notifications",
            "guide.notifications_body": "Turn on notifications to get warnings before unsafe conditions.",
            "guide.high_risk_title": "What to do at high risk",
            "guide.high_risk_body": "Reduce outdoor intensity, avoid peak heat, ventilate during safe windows, and follow recommendations.",
            "guide.not_doctor_title": "Why HiAir is not a doctor replacement",
            "guide.not_doctor_body": "HiAir supports daily decisions but does not provide diagnosis or replace medical care.",
            "guide.faq_title": "FAQ",
            "guide.faq_body": "If data is temporarily unavailable, refresh the screen or try again later.",
            "ai_guide.title": "HiAir AI Assistant",
            "ai_guide.placeholder": "Ask how to use the app...",
            "ai_guide.send": "Ask",
            "ai_guide.clear": "New chat",
            "ai_guide.greeting": "Hi! I am your HiAir AI Assistant. Ask a question and I will reply with clear step-by-step actions.",
            "ai_guide.subtitle": "I can guide you and open the right screen",
            "ai_guide.language_hint": "Answering in app language:",
            "ai_guide.user_label": "You",
            "ai_guide.assistant_label": "HiAir Assistant",
            "ai_guide.followup": "Need more detail? Ask a follow-up and I will break it down further.",
            "ai_guide.action.open_dashboard": "Open Dashboard",
            "ai_guide.action.open_planner": "Open Planner",
            "ai_guide.action.open_insights": "Open Insights",
            "ai_guide.action.open_symptoms": "Open Symptoms",
            "ai_guide.action.open_notifications": "Open Settings",
            "ai_guide.action.open_account": "Open Account",
            "ai_guide.action.open_onboarding": "Start onboarding",
            "ai_guide.suggestion.onboarding": "How do I start using the app?",
            "ai_guide.suggestion.risk": "How do I interpret Risk, AQI, and PM2.5?",
            "ai_guide.suggestion.safe_windows": "How do I use safe windows?",
            "ai_guide.suggestion.notifications": "How do I enable notifications?",
            "ai_guide.suggestion.symptoms": "How do I log symptoms?",
            "ai_guide.suggestion.account": "How do I manage my account and data?",
            "ai_guide.intent.onboarding.title": "How to start with HiAir:",
            "ai_guide.intent.onboarding.step1": "Sign in or register on the account screen.",
            "ai_guide.intent.onboarding.step2": "Complete onboarding and select who you use HiAir for.",
            "ai_guide.intent.onboarding.step3": "On Dashboard, review Risk Score and the “Get Started” checklist.",
            "ai_guide.intent.onboarding.step4": "Open Planner and review safe windows for today.",
            "ai_guide.intent.risk.title": "How to read risk metrics:",
            "ai_guide.intent.risk.step1": "Start with Risk Score - it reflects your personalized overall risk level.",
            "ai_guide.intent.risk.step2": "AQI shows total air pollution burden: higher value means worse air.",
            "ai_guide.intent.risk.step3": "PM2.5 and ozone show factors that often worsen breathing comfort.",
            "ai_guide.intent.risk.step4": "At high risk, follow recommendations and schedule around safe windows.",
            "ai_guide.intent.planner.title": "How to use the forecast and safe windows:",
            "ai_guide.intent.planner.step1": "Open the Planner tab.",
            "ai_guide.intent.planner.step2": "Check hourly risk and identify lower-risk time intervals.",
            "ai_guide.intent.planner.step3": "Move walks, sports, or ventilation to safe windows.",
            "ai_guide.intent.planner.step4": "If no safe interval exists, reduce outdoor load and re-check later.",
            "ai_guide.intent.notifications.title": "How to set up notifications:",
            "ai_guide.intent.notifications.step1": "Open Settings > Notifications.",
            "ai_guide.intent.notifications.step2": "Enable push notifications and, if needed, Morning Briefing.",
            "ai_guide.intent.notifications.step3": "Set alert threshold and quiet hours for your daily routine.",
            "ai_guide.intent.notifications.step4": "Save settings and confirm the checklist item is marked as done.",
            "ai_guide.intent.symptoms.title": "How to log symptoms and use insights:",
            "ai_guide.intent.symptoms.step1": "Open Symptoms tab and track your status regularly.",
            "ai_guide.intent.symptoms.step2": "Use quick buttons when you need fast logging.",
            "ai_guide.intent.symptoms.step3": "After accumulating data, open Insights for personal patterns.",
            "ai_guide.intent.symptoms.step4": "Use those patterns with weather and air data to plan your day.",
            "ai_guide.intent.account.title": "How to manage account, profile, and privacy:",
            "ai_guide.intent.account.step1": "In Settings, review your email, language, and default profile.",
            "ai_guide.intent.account.step2": "Use “Export my data” when you need a privacy copy.",
            "ai_guide.intent.account.step3": "You can log out or delete your account when needed.",
            "ai_guide.intent.account.step4": "After changes, sync settings using the button at the bottom.",
            "ai_guide.intent.fallback.title": "Universal plan for any question:",
            "ai_guide.intent.fallback.step1": "Describe your goal in one sentence.",
            "ai_guide.intent.fallback.step2": "Tell me which screen you are currently on.",
            "ai_guide.intent.fallback.step3": "I will provide the exact button-by-button path.",
            "ai_guide.intent.fallback.step4": "If something fails, send the error text and I will provide a fix plan.",
        ]
    ]

    private static let localizedOverrides: [String: [String: String]] = [
        "es": [
            "tab.dashboard": "Inicio",
            "tab.planner": "Plan",
            "tab.insights": "Insights",
            "tab.symptoms": "Síntomas",
            "tab.settings": "Ajustes",
            "title.settings": "Ajustes",
            "auth.title": "Cuenta HiAir",
            "brand.tagline": "Breathe better. Live better.",
            "auth.email": "Correo",
            "auth.password": "Contraseña (mín. 12 caracteres, A/a/0-9/símbolo)",
            "auth.sign_up": "Registrarse",
            "auth.log_in": "Iniciar sesión",
            "auth.sign_in_apple": "Iniciar sesión con Apple",
            "auth.sign_in_google": "Iniciar sesión con Google",
            "auth.enter_email": "Introduce el correo.",
            "auth.password_short": "La contraseña debe tener al menos 12 caracteres.",
            "onboarding.start": "Comenzar",
            "onboarding.next": "Siguiente",
            "onboarding.back": "Atrás",
            "onboarding.step1.title": "HiAir es tu asistente de calor y calidad del aire",
            "onboarding.step1.body": "HiAir te ayuda a entender cuándo el calor y el aire exterior pueden ser inseguros para ti.",
            "onboarding.step2.title": "Qué problemas resuelve HiAir",
            "onboarding.step3.title": "¿Para quién usas HiAir?",
            "onboarding.step4.title": "Qué revisar cada día",
            "onboarding.step5.title": "Por qué importan los permisos",
            "onboarding.step6.title": "Todo listo",
            "onboarding.open_forecast": "Abrir mi pronóstico",
            "wearable.consent.title": "Conecta salud y actividad",
            "wearable.consent.body": "HiAir puede estimar mejor tu carga corporal durante calor y mal aire. Podemos usar pasos, pulso y pulso en reposo.",
            "wearable.consent.disclaimer": "HiAir ofrece bienestar, no diagnóstico médico.",
            "wearable.consent.connect": "Conectar",
            "wearable.consent.skip": "Omitir",
            "wearable.consent.saving": "Guardando conexión…",
            "wearable.consent.failed": "No se pudo guardar el consentimiento. Inténtalo de nuevo.",
            "wearable.consent.retry": "Reintentar",
            "wearable.consent.connected": "Salud conectada",
            "wearable.consent.revoking": "Desconectando salud…",
            "wearable.consent.revoke_failed": "No se pudo completar la desconexión en el servidor. Reintenta.",
            "wearable.dashboard.title": "Carga hoy",
            "wearable.dashboard.steps": "Pasos",
            "wearable.dashboard.hr_normal": "Pulso: normal",
            "wearable.dashboard.hr_elevated": "Pulso: por encima de lo habitual",
            "wearable.dashboard.hr_unknown": "Pulso: pocos datos",
            "wearable.dashboard.load_risk": "Riesgo de carga",
            "wearable.dashboard.not_connected": "Conecta salud para estimar mejor la carga en calor.",
            "wearable.dashboard.denied": "Acceso a Apple Salud desactivado.",
            "wearable.dashboard.open_settings": "Abrir ajustes",
            "wearable.dashboard.open_health": "Abrir Salud",
            "wearable.dashboard.health_path": "En Salud: Perfil → Privacidad → Apps → HiAir → activa Pasos y Ritmo cardíaco.",
            "wearable.dashboard.unavailable": "Pocos datos hoy. El análisis usa clima y calidad del aire.",
            "wearable.load.none": "sin datos",
            "wearable.load.low": "bajo",
            "wearable.load.moderate": "medio",
            "wearable.load.elevated": "elevado",
            "settings.wearables.title": "Health & Wearables",
            "settings.wearables.status": "Apple Health",
            "settings.wearables.connect": "Conectar Apple Salud",
            "settings.wearables.connected": "conectado",
            "settings.wearables.device_authorized": "acceso permitido",
            "settings.wearables.consent_inactive": "consentimiento inactivo",
            "settings.wearables.denied": "acceso denegado",
            "settings.wearables.disconnect": "Desconectar",
            "settings.wearables.delete": "Eliminar datos de salud",
            "settings.wearables.delete_done": "Datos de salud locales eliminados",
            "settings.wearables.delete_confirm": "¿Eliminar todos los resúmenes de salud?",
            "dashboard.hazards.title": "Peligros ambientales",
            "dashboard.hazards.empty": "Aún no hay evaluaciones de peligros.",
            "dashboard.hazards.unavailable": "—",
            "hazard.type.heat": "Calor",
            "hazard.type.air": "Aire",
            "hazard.type.uv": "UV",
            "hazard.type.pollen": "Polen",
            "hazard.type.smoke": "Humo",
            "hazard.type.dust": "Polvo",
            "hazard.level.low": "bajo",
            "hazard.level.moderate": "moderado",
            "hazard.level.high": "alto",
            "hazard.level.very_high": "muy alto",
            "hazard.level.unavailable": "no disponible",
            "settings.places.title": "Lugares guardados",
            "settings.places.empty": "Aún no hay lugares guardados.",
            "settings.places.coords": "%.4f, %.4f",
            "settings.places.delete": "Eliminar",
            "settings.places.add_home": "Añadir hogar actual",
            "settings.places.home_default_name": "Hogar",
            "settings.places.added": "Lugar guardado",
            "settings.places.add_failed": "No se pudo guardar el lugar",
            "settings.places.deleted": "Lugar eliminado",
            "settings.places.delete_failed": "No se pudo eliminar el lugar",
            "settings.places.load_failed": "No se pudieron cargar los lugares",
            "insights.adaptation.title": "Adaptación y días protegidos",
            "insights.adaptation.baselines.empty": "Las líneas base personales aún no están disponibles.",
            "insights.adaptation.baseline_line": "%@ (%@): %.0f",
            "insights.adaptation.protected_days": "Periodos de alto riesgo evitados: %d · Entrenamientos movidos: %d · Ventanas de ventilación: %d · Exposición al mal aire reducida: %d",
            "insights.adaptation.metric.resting_heart_rate": "Pulso en reposo",
            "insights.adaptation.metric.hrv": "HRV",
            "insights.adaptation.metric.sleep_minutes": "Sueño (min)",
            "insights.adaptation.metric.steps": "Pasos",
            "insights.adaptation.metric.exercise_minutes": "Ejercicio (min)",
            "insights.adaptation.window.d7": "7 días",
            "insights.adaptation.window.d30": "30 días",
            "common.loading": "Cargando…",
            "common.retry": "Reintentar",
            "common.error.title": "No se pudo cargar",
            "common.error.network": "Comprueba tu conexión e inténtalo de nuevo.",
            "state.empty.title": "Aún no hay datos",
            "state.empty.body": "Cuando haya datos, HiAir mostrará un resultado claro y el siguiente paso.",
            "state.empty.insights.title": "Pocos registros para insights",
            "state.empty.insights.body": "Registra síntomas unos días más para que HiAir encuentre patrones personales.",
            "state.loading": "Cargando…",
            "status.excellent": "Excelente",
            "status.good": "Bueno",
            "status.moderate": "Moderado",
            "status.bad": "Malo",
            "dashboard.title": "Inteligencia diaria del aire",
            "dashboard.get_started.title": "Cómo empezar",
            "dashboard.get_started.hide": "Ocultar",
            "dashboard.get_started.item.risk": "Revisa el nivel de riesgo actual",
            "dashboard.get_started.item.hourly": "Abre el pronóstico por hora",
            "dashboard.get_started.item.recommendations": "Lee las recomendaciones",
            "dashboard.get_started.item.profile": "Configura tu perfil",
            "dashboard.get_started.item.notifications": "Activa notificaciones",
            "dashboard.air_metrics": "Métricas del aire",
            "dashboard.metric.ozone": "Ozono",
            "dashboard.metric.humidity": "Humedad",
            "dashboard.do_now": "Qué hacer ahora",
            "dashboard.safe_windows": "Ventanas seguras",
            "planner.title": "Plan diario",
            "planner.refresh": "Actualizar plan",
            "planner.forecast_partial": "El pronóstico está parcialmente disponible: faltan algunas métricas.",
            "planner.forecast_unavailable": "El pronóstico por horas no está disponible ahora.",
            "planner.freshness.live": "Pronóstico actualizado",
            "planner.freshness.cached": "Mostrando un pronóstico en caché",
            "planner.freshness.stale": "El pronóstico está desactualizado",
            "planner.sources": "Fuente",
            "planner.activity.title": "Mejor momento para la actividad",
            "planner.activity.subtitle": "Elige una actividad: HiAir muestra ventanas mejores, aceptables y a evitar.",
            "planner.activity.picker": "Actividad",
            "planner.activity.place": "Lugar",
            "planner.activity.place_home": "Ubicacion de casa",
            "planner.activity.mark_planned": "Marcar entrenamiento movido",
            "planner.activity.mark_planned_done": "Guardado en dias protegidos",
            "planner.activity.mark_planned_failed": "No se pudo guardar",
            "planner.activity.loading": "Buscando el mejor momento…",
            "planner.activity.recommended": "Inicio recomendado: %@",
            "planner.activity.no_windows": "No hay ventanas adecuadas hoy.",
            "planner.activity.forecast_unavailable": "El pronóstico para planificar actividad no está disponible.",
            "planner.activity.tier.best": "Mejor",
            "planner.activity.tier.acceptable": "Aceptable",
            "planner.activity.tier.avoid": "Evitar",
            "planner.activity.running": "Correr",
            "planner.activity.walking": "Caminar",
            "planner.activity.cycling": "Ciclismo",
            "planner.activity.hiking": "Senderismo",
            "planner.activity.dog_walk": "Paseo con perro",
            "planner.activity.playground": "Parque infantil",
            "planner.activity.outdoor_sport": "Deporte al aire libre",
            "planner.activity.beach": "Playa",
            "planner.activity.outdoor_work": "Trabajo exterior",
            "planner.activity.ventilation": "Ventilación",
            "planner.activity.reason.aqi": "AQI",
            "planner.activity.reason.pm25": "PM2.5",
            "planner.activity.reason.ozone": "Ozono",
            "planner.activity.reason.air": "Calidad del aire",
            "planner.activity.reason.heat": "Calor",
            "planner.activity.reason.uv": "UV",
            "planner.activity.reason.uv_unavailable": "UV no disponible",
            "planner.activity.reason.air_data_unavailable": "Datos de aire no disponibles",
            "planner.activity.reason.personal_load": "Carga personal",
            "planner.activity.reason.child_caution": "Precaución infantil",
            "planner.activity.reason.low_heat": "Calor bajo",
            "planner.activity.reason.good_air": "Buen aire",
            "dashboard.metric.unavailable": "No disponible",
            "symptoms.title": "Registro de síntomas",
            "symptoms.submit": "Enviar síntomas",
            "settings.help_title": "Ayuda",
            "settings.help_open": "Guía HiAir",
            "settings.language_ru": "Ruso",
            "settings.language_en": "Inglés",
            "settings.language_es": "Español",
            "settings.language_it": "Italiano",
            "settings.language_fr": "Francés",
            "settings.ai_guide_open": "Asistente IA",
            "ai_guide.title": "Asistente IA de HiAir",
            "ai_guide.placeholder": "Pregunta cómo usar la app...",
            "ai_guide.send": "Preguntar",
            "ai_guide.clear": "Nuevo chat",
            "ai_guide.greeting": "Hola. Soy tu asistente IA de HiAir. Haz una pregunta y te responderé con pasos claros.",
            "ai_guide.subtitle": "Puedo guiarte y abrir la pantalla correcta",
            "ai_guide.language_hint": "Respondo en el idioma de la app:",
            "ai_guide.user_label": "Tú",
            "ai_guide.assistant_label": "Asistente HiAir",
            "ai_guide.followup": "¿Necesitas más detalle? Haz una pregunta adicional y lo detallo paso a paso.",
            "ai_guide.action.open_dashboard": "Abrir Inicio",
            "ai_guide.action.open_planner": "Abrir Plan",
            "ai_guide.action.open_insights": "Abrir Insights",
            "ai_guide.action.open_symptoms": "Abrir Síntomas",
            "ai_guide.action.open_notifications": "Abrir Ajustes",
            "ai_guide.action.open_account": "Abrir Cuenta",
            "ai_guide.action.open_onboarding": "Iniciar onboarding",
            "ai_guide.suggestion.onboarding": "¿Cómo empiezo a usar la app?",
            "ai_guide.suggestion.risk": "¿Cómo interpreto Risk, AQI y PM2.5?",
            "ai_guide.suggestion.safe_windows": "¿Cómo uso las ventanas seguras?",
            "ai_guide.suggestion.notifications": "¿Cómo activo las notificaciones?",
            "ai_guide.suggestion.symptoms": "¿Cómo registro síntomas?",
            "ai_guide.suggestion.account": "¿Cómo gestiono mi cuenta y datos?",
            "ai_guide.intent.onboarding.title": "Cómo empezar con HiAir:",
            "ai_guide.intent.onboarding.step1": "Inicia sesión o regístrate en la pantalla de cuenta.",
            "ai_guide.intent.onboarding.step2": "Completa el onboarding y elige para quién usas HiAir.",
            "ai_guide.intent.onboarding.step3": "En Inicio, revisa Risk Score y la lista “Cómo empezar”.",
            "ai_guide.intent.onboarding.step4": "Abre Plan y revisa las ventanas seguras de hoy.",
            "ai_guide.intent.risk.title": "Cómo interpretar las métricas de riesgo:",
            "ai_guide.intent.risk.step1": "Empieza por Risk Score: es tu riesgo general personalizado.",
            "ai_guide.intent.risk.step2": "AQI muestra la carga total de contaminación: cuanto más alto, peor aire.",
            "ai_guide.intent.risk.step3": "PM2.5 y ozono muestran factores que suelen empeorar la respiración.",
            "ai_guide.intent.risk.step4": "Con riesgo alto, sigue recomendaciones y planifica con ventanas seguras.",
            "ai_guide.intent.planner.title": "Cómo usar el pronóstico y las ventanas seguras:",
            "ai_guide.intent.planner.step1": "Abre la pestaña Plan.",
            "ai_guide.intent.planner.step2": "Revisa el riesgo por hora e identifica intervalos de menor riesgo.",
            "ai_guide.intent.planner.step3": "Mueve paseos, deporte o ventilación a las ventanas seguras.",
            "ai_guide.intent.planner.step4": "Si no hay ventanas, reduce actividad exterior y revisa más tarde.",
            "ai_guide.intent.notifications.title": "Cómo configurar notificaciones:",
            "ai_guide.intent.notifications.step1": "Abre Ajustes > Notificaciones.",
            "ai_guide.intent.notifications.step2": "Activa push y, si quieres, Morning Briefing.",
            "ai_guide.intent.notifications.step3": "Define umbral de alerta y horas de silencio según tu rutina.",
            "ai_guide.intent.notifications.step4": "Guarda ajustes y confirma que el checklist está marcado.",
            "ai_guide.intent.symptoms.title": "Cómo registrar síntomas y usar insights:",
            "ai_guide.intent.symptoms.step1": "Abre Síntomas y registra tu estado con regularidad.",
            "ai_guide.intent.symptoms.step2": "Usa botones rápidos cuando necesites un registro inmediato.",
            "ai_guide.intent.symptoms.step3": "Con más datos, abre Insights para ver patrones personales.",
            "ai_guide.intent.symptoms.step4": "Usa esos patrones junto al clima para planificar tu día.",
            "ai_guide.intent.account.title": "Cómo gestionar cuenta, perfil y privacidad:",
            "ai_guide.intent.account.step1": "En Ajustes revisa User ID, idioma y perfil por defecto.",
            "ai_guide.intent.account.step2": "Usa “Exportar mis datos” cuando necesites copia de privacidad.",
            "ai_guide.intent.account.step3": "Puedes cerrar sesión o eliminar cuenta cuando sea necesario.",
            "ai_guide.intent.account.step4": "Después de cambios, sincroniza desde el botón inferior.",
            "ai_guide.intent.fallback.title": "Plan universal para cualquier pregunta:",
            "ai_guide.intent.fallback.step1": "Describe qué quieres hacer en la app.",
            "ai_guide.intent.fallback.step2": "Dime en qué pantalla estás ahora.",
            "ai_guide.intent.fallback.step3": "Te daré el camino exacto, botón por botón.",
            "ai_guide.intent.fallback.step4": "Si algo falla, envía el texto del error y te ayudo a corregirlo.",
            "guide.title": "Guía HiAir",
            "guide.what_is_title": "Qué es HiAir",
            "guide.problems_title": "Qué problemas resuelve",
            "guide.for_whom_title": "Para quién es útil",
            "guide.read_dashboard_title": "Cómo leer la pantalla principal",
            "guide.risk_title": "Qué significa Risk Score",
            "guide.metrics_title": "Qué son AQI, PM2.5, ozono, humedad y calor",
            "guide.hourly_title": "Cómo usar el pronóstico por hora",
            "guide.safe_windows_title": "Qué son las ventanas seguras",
            "guide.symptoms_title": "Cómo usar el registro de síntomas",
            "guide.notifications_title": "Cómo configurar notificaciones",
            "guide.high_risk_title": "Qué hacer con riesgo alto",
            "guide.not_doctor_title": "Por qué HiAir no sustituye al médico",
            "guide.faq_title": "Preguntas frecuentes",
        ],
        "it": [
            "tab.dashboard": "Home",
            "tab.planner": "Piano",
            "tab.insights": "Insights",
            "tab.symptoms": "Sintomi",
            "tab.settings": "Impostazioni",
            "title.settings": "Impostazioni",
            "auth.title": "Account HiAir",
            "brand.tagline": "Breathe better. Live better.",
            "auth.email": "Email",
            "auth.password": "Password (min. 12 caratteri, A/a/0-9/simbolo)",
            "auth.sign_up": "Registrati",
            "auth.log_in": "Accedi",
            "auth.sign_in_apple": "Accedi con Apple",
            "auth.sign_in_google": "Accedi con Google",
            "auth.enter_email": "Inserisci email.",
            "auth.password_short": "La password deve avere almeno 12 caratteri.",
            "onboarding.start": "Inizia",
            "onboarding.next": "Avanti",
            "onboarding.back": "Indietro",
            "onboarding.step1.title": "HiAir e il tuo assistente per calore e qualita dell'aria",
            "onboarding.step1.body": "HiAir ti aiuta a capire quando il caldo e l'aria esterna possono essere rischiosi per te.",
            "onboarding.step2.title": "Quali problemi risolve HiAir",
            "onboarding.step3.title": "Per chi usi HiAir?",
            "onboarding.step4.title": "Cosa controllare ogni giorno",
            "onboarding.step5.title": "Perché i permessi sono importanti",
            "onboarding.step6.title": "Tutto pronto",
            "onboarding.open_forecast": "Apri la mia previsione",
            "dashboard.title": "Intelligenza quotidiana dell'aria",
            "dashboard.get_started.title": "Come iniziare",
            "dashboard.get_started.hide": "Nascondi",
            "dashboard.get_started.item.risk": "Controlla il livello di rischio attuale",
            "dashboard.get_started.item.hourly": "Apri la previsione oraria",
            "dashboard.get_started.item.recommendations": "Leggi le raccomandazioni",
            "dashboard.get_started.item.profile": "Configura il profilo",
            "dashboard.get_started.item.notifications": "Attiva le notifiche",
            "dashboard.air_metrics": "Metriche dell'aria",
            "dashboard.hazards.title": "Pericoli ambientali",
            "dashboard.hazards.empty": "Nessuna valutazione dei pericoli disponibile.",
            "dashboard.hazards.unavailable": "—",
            "hazard.type.heat": "Calore",
            "hazard.type.air": "Aria",
            "hazard.type.uv": "UV",
            "hazard.type.pollen": "Polline",
            "hazard.type.smoke": "Fumo",
            "hazard.type.dust": "Polvere",
            "hazard.level.low": "basso",
            "hazard.level.moderate": "moderato",
            "hazard.level.high": "alto",
            "hazard.level.very_high": "molto alto",
            "hazard.level.unavailable": "non disponibile",
            "settings.places.title": "Luoghi salvati",
            "settings.places.empty": "Nessun luogo salvato.",
            "settings.places.coords": "%.4f, %.4f",
            "settings.places.delete": "Elimina",
            "settings.places.add_home": "Aggiungi casa attuale",
            "settings.places.home_default_name": "Casa",
            "settings.places.added": "Luogo salvato",
            "settings.places.add_failed": "Impossibile salvare il luogo",
            "settings.places.deleted": "Luogo eliminato",
            "settings.places.delete_failed": "Impossibile eliminare il luogo",
            "settings.places.load_failed": "Impossibile caricare i luoghi",
            "insights.adaptation.title": "Adattamento e giorni protetti",
            "insights.adaptation.baselines.empty": "Le baseline personali non sono ancora disponibili.",
            "insights.adaptation.baseline_line": "%@ (%@): %.0f",
            "insights.adaptation.protected_days": "Periodi ad alto rischio evitati: %d · Allenamenti spostati: %d · Finestre di ventilazione: %d · Esposizione ad aria scadente ridotta: %d",
            "insights.adaptation.metric.resting_heart_rate": "Frequenza cardiaca a riposo",
            "insights.adaptation.metric.hrv": "HRV",
            "insights.adaptation.metric.sleep_minutes": "Sonno (min)",
            "insights.adaptation.metric.steps": "Passi",
            "insights.adaptation.metric.exercise_minutes": "Esercizio (min)",
            "insights.adaptation.window.d7": "7 giorni",
            "insights.adaptation.window.d30": "30 giorni",
            "dashboard.metric.ozone": "Ozono",
            "dashboard.metric.humidity": "Umidita",
            "dashboard.do_now": "Cosa fare ora",
            "dashboard.safe_windows": "Finestre sicure",
            "planner.title": "Piano giornaliero",
            "planner.refresh": "Aggiorna piano",
            "planner.forecast_partial": "La previsione e parzialmente disponibile: mancano alcune metriche.",
            "planner.forecast_unavailable": "La previsione oraria non e disponibile ora.",
            "planner.freshness.live": "Previsione aggiornata",
            "planner.freshness.cached": "Mostro una previsione in cache",
            "planner.freshness.stale": "La previsione e obsoleta",
            "planner.sources": "Fonte",
            "planner.activity.title": "Momento migliore per l'attivita",
            "planner.activity.subtitle": "Scegli un'attivita: HiAir mostra finestre migliori, accettabili e da evitare.",
            "planner.activity.picker": "Attivita",
            "planner.activity.place": "Luogo",
            "planner.activity.place_home": "Posizione di casa",
            "planner.activity.mark_planned": "Segna allenamento spostato",
            "planner.activity.mark_planned_done": "Salvato nei giorni protetti",
            "planner.activity.mark_planned_failed": "Impossibile salvare",
            "planner.activity.loading": "Cerco il momento migliore…",
            "planner.activity.recommended": "Inizio consigliato: %@",
            "planner.activity.no_windows": "Nessuna finestra adatta oggi.",
            "planner.activity.forecast_unavailable": "La previsione per pianificare l'attivita non e disponibile.",
            "planner.activity.tier.best": "Migliore",
            "planner.activity.tier.acceptable": "Accettabile",
            "planner.activity.tier.avoid": "Evitare",
            "planner.activity.running": "Corsa",
            "planner.activity.walking": "Camminata",
            "planner.activity.cycling": "Ciclismo",
            "planner.activity.hiking": "Escursionismo",
            "planner.activity.dog_walk": "Passeggiata col cane",
            "planner.activity.playground": "Parco giochi",
            "planner.activity.outdoor_sport": "Sport all'aperto",
            "planner.activity.beach": "Spiaggia",
            "planner.activity.outdoor_work": "Lavoro all'aperto",
            "planner.activity.ventilation": "Ventilazione",
            "planner.activity.reason.aqi": "AQI",
            "planner.activity.reason.pm25": "PM2.5",
            "planner.activity.reason.ozone": "Ozono",
            "planner.activity.reason.air": "Qualita dell'aria",
            "planner.activity.reason.heat": "Caldo",
            "planner.activity.reason.uv": "UV",
            "planner.activity.reason.uv_unavailable": "UV non disponibile",
            "planner.activity.reason.air_data_unavailable": "Dati aria non disponibili",
            "planner.activity.reason.personal_load": "Carico personale",
            "planner.activity.reason.child_caution": "Attenzione bambini",
            "planner.activity.reason.low_heat": "Caldo basso",
            "planner.activity.reason.good_air": "Aria buona",
            "dashboard.metric.unavailable": "Non disponibile",
            "symptoms.title": "Registro sintomi",
            "symptoms.submit": "Invia sintomi",
            "settings.help_title": "Aiuto",
            "settings.help_open": "Guida HiAir",
            "settings.language_ru": "Russo",
            "settings.language_en": "Inglese",
            "settings.language_es": "Spagnolo",
            "settings.language_it": "Italiano",
            "settings.language_fr": "Francese",
            "settings.ai_guide_open": "Assistente IA",
            "ai_guide.title": "Assistente IA di HiAir",
            "ai_guide.placeholder": "Chiedi come usare l'app...",
            "ai_guide.send": "Chiedi",
            "ai_guide.clear": "Nuova chat",
            "ai_guide.greeting": "Ciao. Sono il tuo assistente IA di HiAir. Fai una domanda e ti risponderò con passaggi chiari.",
            "ai_guide.subtitle": "Posso guidarti e aprire la schermata corretta",
            "ai_guide.language_hint": "Rispondo nella lingua dell'app:",
            "ai_guide.user_label": "Tu",
            "ai_guide.assistant_label": "Assistente HiAir",
            "ai_guide.followup": "Serve più dettaglio? Fai una domanda di follow-up e lo spiego passo passo.",
            "ai_guide.action.open_dashboard": "Apri Home",
            "ai_guide.action.open_planner": "Apri Piano",
            "ai_guide.action.open_insights": "Apri Insights",
            "ai_guide.action.open_symptoms": "Apri Sintomi",
            "ai_guide.action.open_notifications": "Apri Impostazioni",
            "ai_guide.action.open_account": "Apri Account",
            "ai_guide.action.open_onboarding": "Avvia onboarding",
            "ai_guide.suggestion.onboarding": "Come inizio a usare l'app?",
            "ai_guide.suggestion.risk": "Come leggo Risk, AQI e PM2.5?",
            "ai_guide.suggestion.safe_windows": "Come uso le finestre sicure?",
            "ai_guide.suggestion.notifications": "Come attivo le notifiche?",
            "ai_guide.suggestion.symptoms": "Come registro i sintomi?",
            "ai_guide.suggestion.account": "Come gestisco account e dati?",
            "ai_guide.intent.onboarding.title": "Come iniziare con HiAir:",
            "ai_guide.intent.onboarding.step1": "Accedi o registrati nella schermata account.",
            "ai_guide.intent.onboarding.step2": "Completa onboarding e scegli per chi usi HiAir.",
            "ai_guide.intent.onboarding.step3": "In Home controlla Risk Score e lista “Come iniziare”.",
            "ai_guide.intent.onboarding.step4": "Apri Piano e verifica le finestre sicure di oggi.",
            "ai_guide.intent.risk.title": "Come leggere le metriche di rischio:",
            "ai_guide.intent.risk.step1": "Parti da Risk Score: e il tuo rischio complessivo personalizzato.",
            "ai_guide.intent.risk.step2": "AQI mostra il carico totale di inquinamento: piu alto, aria peggiore.",
            "ai_guide.intent.risk.step3": "PM2.5 e ozono indicano fattori che peggiorano il respiro.",
            "ai_guide.intent.risk.step4": "Con rischio alto, segui le raccomandazioni e usa finestre sicure.",
            "ai_guide.intent.planner.title": "Come usare previsione e finestre sicure:",
            "ai_guide.intent.planner.step1": "Apri la scheda Piano.",
            "ai_guide.intent.planner.step2": "Controlla rischio orario e trova intervalli a rischio minore.",
            "ai_guide.intent.planner.step3": "Sposta passeggiate, sport o ventilazione nelle finestre sicure.",
            "ai_guide.intent.planner.step4": "Se non ci sono finestre, riduci attivita esterna e ricontrolla.",
            "ai_guide.intent.notifications.title": "Come configurare le notifiche:",
            "ai_guide.intent.notifications.step1": "Apri Impostazioni > Notifiche.",
            "ai_guide.intent.notifications.step2": "Attiva push e, se serve, Morning Briefing.",
            "ai_guide.intent.notifications.step3": "Imposta soglia alert e ore silenziose per la tua routine.",
            "ai_guide.intent.notifications.step4": "Salva impostazioni e verifica checklist completata.",
            "ai_guide.intent.symptoms.title": "Come registrare sintomi e usare insights:",
            "ai_guide.intent.symptoms.step1": "Apri Sintomi e registra regolarmente il tuo stato.",
            "ai_guide.intent.symptoms.step2": "Usa pulsanti rapidi quando serve un log veloce.",
            "ai_guide.intent.symptoms.step3": "Con piu dati, apri Insights per pattern personali.",
            "ai_guide.intent.symptoms.step4": "Usa i pattern con meteo e aria per pianificare la giornata.",
            "ai_guide.intent.account.title": "Come gestire account, profilo e privacy:",
            "ai_guide.intent.account.step1": "In Impostazioni controlla User ID, lingua e profilo predefinito.",
            "ai_guide.intent.account.step2": "Usa “Esporta i miei dati” per una copia privacy.",
            "ai_guide.intent.account.step3": "Puoi uscire o eliminare account quando necessario.",
            "ai_guide.intent.account.step4": "Dopo le modifiche, sincronizza con il pulsante in basso.",
            "ai_guide.intent.fallback.title": "Piano universale per qualsiasi domanda:",
            "ai_guide.intent.fallback.step1": "Descrivi cosa vuoi fare nell'app.",
            "ai_guide.intent.fallback.step2": "Dimmi in quale schermata ti trovi.",
            "ai_guide.intent.fallback.step3": "Ti darò il percorso esatto, pulsante per pulsante.",
            "ai_guide.intent.fallback.step4": "Se qualcosa non funziona, invia il testo dell'errore e ti aiuto.",
            "guide.title": "Guida HiAir",
            "guide.what_is_title": "Che cos'e HiAir",
            "guide.problems_title": "Quali problemi risolve",
            "guide.for_whom_title": "Per chi e utile",
            "guide.read_dashboard_title": "Come leggere la schermata principale",
            "guide.risk_title": "Cosa significa Risk Score",
            "guide.metrics_title": "Cosa sono AQI, PM2.5, ozono, umidita e calore",
            "guide.hourly_title": "Come usare la previsione oraria",
            "guide.safe_windows_title": "Cosa sono le finestre sicure",
            "guide.symptoms_title": "Come usare il registro sintomi",
            "guide.notifications_title": "Come configurare le notifiche",
            "guide.high_risk_title": "Cosa fare con rischio alto",
            "guide.not_doctor_title": "Perché HiAir non sostituisce il medico",
            "guide.faq_title": "Domande frequenti",
            "settings.wearables.device_authorized": "accesso consentito",
            "settings.wearables.consent_inactive": "consenso inattivo",
            "settings.wearables.connected": "connesso",
            "settings.wearables.disconnect": "Disconnetti",
            "settings.wearables.delete": "Elimina dati health",
            "settings.wearables.delete_done": "Dati health locali eliminati",
            "settings.wearables.connect": "Collega Apple Health",
        ],
        "fr": [
            "tab.dashboard": "Accueil",
            "tab.planner": "Plan",
            "tab.insights": "Insights",
            "tab.symptoms": "Symptomes",
            "tab.settings": "Parametres",
            "title.settings": "Parametres",
            "auth.title": "Compte HiAir",
            "brand.tagline": "Breathe better. Live better.",
            "auth.email": "Email",
            "auth.password": "Mot de passe (min. 12 caracteres, A/a/0-9/symbole)",
            "auth.sign_up": "S'inscrire",
            "auth.log_in": "Se connecter",
            "auth.sign_in_apple": "Se connecter avec Apple",
            "auth.sign_in_google": "Se connecter avec Google",
            "auth.enter_email": "Entrez votre email.",
            "auth.password_short": "Le mot de passe doit contenir au moins 12 caracteres.",
            "onboarding.start": "Commencer",
            "onboarding.next": "Suivant",
            "onboarding.back": "Retour",
            "onboarding.step1.title": "HiAir est votre assistant chaleur et qualite de l'air",
            "onboarding.step1.body": "HiAir vous aide a comprendre quand la chaleur et l'air exterieur peuvent etre risqués pour vous.",
            "onboarding.step2.title": "Quels problemes HiAir resout",
            "onboarding.step3.title": "Pour qui utilisez-vous HiAir ?",
            "onboarding.step4.title": "Que verifier chaque jour",
            "onboarding.step5.title": "Pourquoi les autorisations comptent",
            "onboarding.step6.title": "C'est pret",
            "onboarding.open_forecast": "Ouvrir ma prevision",
            "dashboard.title": "Intelligence quotidienne de l'air",
            "dashboard.get_started.title": "Comment commencer",
            "dashboard.get_started.hide": "Masquer",
            "dashboard.get_started.item.risk": "Verifier le niveau de risque actuel",
            "dashboard.get_started.item.hourly": "Ouvrir la prevision horaire",
            "dashboard.get_started.item.recommendations": "Lire les recommandations",
            "dashboard.get_started.item.profile": "Configurer le profil",
            "dashboard.get_started.item.notifications": "Activer les notifications",
            "dashboard.air_metrics": "Indicateurs de l'air",
            "dashboard.hazards.title": "Dangers environnementaux",
            "dashboard.hazards.empty": "Aucune evaluation de danger pour le moment.",
            "dashboard.hazards.unavailable": "—",
            "hazard.type.heat": "Chaleur",
            "hazard.type.air": "Air",
            "hazard.type.uv": "UV",
            "hazard.type.pollen": "Pollen",
            "hazard.type.smoke": "Fumee",
            "hazard.type.dust": "Poussiere",
            "hazard.level.low": "faible",
            "hazard.level.moderate": "modere",
            "hazard.level.high": "eleve",
            "hazard.level.very_high": "tres eleve",
            "hazard.level.unavailable": "indisponible",
            "settings.places.title": "Lieux enregistres",
            "settings.places.empty": "Aucun lieu enregistre.",
            "settings.places.coords": "%.4f, %.4f",
            "settings.places.delete": "Supprimer",
            "settings.places.add_home": "Ajouter le domicile actuel",
            "settings.places.home_default_name": "Domicile",
            "settings.places.added": "Lieu enregistre",
            "settings.places.add_failed": "Impossible d'enregistrer le lieu",
            "settings.places.deleted": "Lieu supprime",
            "settings.places.delete_failed": "Impossible de supprimer le lieu",
            "settings.places.load_failed": "Impossible de charger les lieux",
            "insights.adaptation.title": "Adaptation et jours proteges",
            "insights.adaptation.baselines.empty": "Les bases personnelles ne sont pas encore disponibles.",
            "insights.adaptation.baseline_line": "%@ (%@): %.0f",
            "insights.adaptation.protected_days": "Periodes a haut risque evitees : %d · Entrainements deplaces : %d · Fenetres de ventilation : %d · Exposition a l'air degrade reduite : %d",
            "insights.adaptation.metric.resting_heart_rate": "Frequence cardiaque au repos",
            "insights.adaptation.metric.hrv": "HRV",
            "insights.adaptation.metric.sleep_minutes": "Sommeil (min)",
            "insights.adaptation.metric.steps": "Pas",
            "insights.adaptation.metric.exercise_minutes": "Exercice (min)",
            "insights.adaptation.window.d7": "7 jours",
            "insights.adaptation.window.d30": "30 jours",
            "dashboard.metric.ozone": "Ozone",
            "dashboard.metric.humidity": "Humidite",
            "dashboard.do_now": "Que faire maintenant",
            "dashboard.safe_windows": "Creneaux surs",
            "planner.title": "Plan quotidien",
            "planner.refresh": "Actualiser le plan",
            "planner.forecast_partial": "La prevision est partiellement disponible : certaines metriques manquent.",
            "planner.forecast_unavailable": "La prevision horaire n'est pas disponible pour le moment.",
            "planner.freshness.live": "Prevision mise a jour",
            "planner.freshness.cached": "Affichage d'une prevision en cache",
            "planner.freshness.stale": "La prevision est obsolete",
            "planner.sources": "Source",
            "planner.activity.title": "Meilleur moment pour l'activite",
            "planner.activity.subtitle": "Choisissez une activite : HiAir affiche les creneaux meilleurs, acceptables et a eviter.",
            "planner.activity.picker": "Activite",
            "planner.activity.place": "Lieu",
            "planner.activity.place_home": "Lieu de domicile",
            "planner.activity.mark_planned": "Marquer entrainement deplace",
            "planner.activity.mark_planned_done": "Enregistre dans les jours proteges",
            "planner.activity.mark_planned_failed": "Enregistrement impossible",
            "planner.activity.loading": "Recherche du meilleur moment…",
            "planner.activity.recommended": "Debut recommande : %@",
            "planner.activity.no_windows": "Aucun creneau adapte aujourd'hui.",
            "planner.activity.forecast_unavailable": "La prevision pour planifier l'activite n'est pas disponible.",
            "planner.activity.tier.best": "Meilleur",
            "planner.activity.tier.acceptable": "Acceptable",
            "planner.activity.tier.avoid": "Eviter",
            "planner.activity.running": "Course",
            "planner.activity.walking": "Marche",
            "planner.activity.cycling": "Velo",
            "planner.activity.hiking": "Randonnee",
            "planner.activity.dog_walk": "Promenade chien",
            "planner.activity.playground": "Aire de jeux",
            "planner.activity.outdoor_sport": "Sport exterieur",
            "planner.activity.beach": "Plage",
            "planner.activity.outdoor_work": "Travail exterieur",
            "planner.activity.ventilation": "Ventilation",
            "planner.activity.reason.aqi": "AQI",
            "planner.activity.reason.pm25": "PM2.5",
            "planner.activity.reason.ozone": "Ozone",
            "planner.activity.reason.air": "Qualite de l'air",
            "planner.activity.reason.heat": "Chaleur",
            "planner.activity.reason.uv": "UV",
            "planner.activity.reason.uv_unavailable": "UV indisponible",
            "planner.activity.reason.air_data_unavailable": "Donnees air indisponibles",
            "planner.activity.reason.personal_load": "Charge personnelle",
            "planner.activity.reason.child_caution": "Prudence enfant",
            "planner.activity.reason.low_heat": "Chaleur faible",
            "planner.activity.reason.good_air": "Bon air",
            "dashboard.metric.unavailable": "Indisponible",
            "symptoms.title": "Journal des symptomes",
            "symptoms.submit": "Envoyer les symptomes",
            "settings.help_title": "Aide",
            "settings.help_open": "Guide HiAir",
            "settings.language_ru": "Russe",
            "settings.language_en": "Anglais",
            "settings.language_es": "Espagnol",
            "settings.language_it": "Italien",
            "settings.language_fr": "Français",
            "settings.ai_guide_open": "Assistant IA",
            "ai_guide.title": "Assistant IA HiAir",
            "ai_guide.placeholder": "Pose une question sur l'application...",
            "ai_guide.send": "Demander",
            "ai_guide.clear": "Nouveau chat",
            "ai_guide.greeting": "Bonjour. Je suis ton assistant IA HiAir. Pose une question et je répondrai avec des étapes claires.",
            "ai_guide.subtitle": "Je peux te guider et ouvrir le bon écran",
            "ai_guide.language_hint": "Je réponds dans la langue de l'application :",
            "ai_guide.user_label": "Vous",
            "ai_guide.assistant_label": "Assistant HiAir",
            "ai_guide.followup": "Besoin de plus de détails ? Pose une question de suivi et je détaillerai étape par étape.",
            "ai_guide.action.open_dashboard": "Ouvrir Accueil",
            "ai_guide.action.open_planner": "Ouvrir Plan",
            "ai_guide.action.open_insights": "Ouvrir Insights",
            "ai_guide.action.open_symptoms": "Ouvrir Symptômes",
            "ai_guide.action.open_notifications": "Ouvrir Paramètres",
            "ai_guide.action.open_account": "Ouvrir Compte",
            "ai_guide.action.open_onboarding": "Lancer l'onboarding",
            "ai_guide.suggestion.onboarding": "Comment commencer à utiliser l'app ?",
            "ai_guide.suggestion.risk": "Comment lire Risk, AQI et PM2.5 ?",
            "ai_guide.suggestion.safe_windows": "Comment utiliser les créneaux sûrs ?",
            "ai_guide.suggestion.notifications": "Comment activer les notifications ?",
            "ai_guide.suggestion.symptoms": "Comment enregistrer les symptômes ?",
            "ai_guide.suggestion.account": "Comment gérer compte et données ?",
            "ai_guide.intent.onboarding.title": "Comment demarrer avec HiAir :",
            "ai_guide.intent.onboarding.step1": "Connectez-vous ou inscrivez-vous sur l'ecran compte.",
            "ai_guide.intent.onboarding.step2": "Terminez l'onboarding et choisissez pour qui vous utilisez HiAir.",
            "ai_guide.intent.onboarding.step3": "Sur Accueil, verifiez Risk Score et la liste “Comment commencer”.",
            "ai_guide.intent.onboarding.step4": "Ouvrez Plan et verifiez les creneaux surs du jour.",
            "ai_guide.intent.risk.title": "Comment lire les indicateurs de risque :",
            "ai_guide.intent.risk.step1": "Commencez par Risk Score : c'est votre risque global personnalise.",
            "ai_guide.intent.risk.step2": "AQI montre la charge totale de pollution : plus c'est haut, pire est l'air.",
            "ai_guide.intent.risk.step3": "PM2.5 et ozone indiquent les facteurs qui aggravent la respiration.",
            "ai_guide.intent.risk.step4": "En risque eleve, suivez recommandations et creneaux surs.",
            "ai_guide.intent.planner.title": "Comment utiliser la prevision et les creneaux surs :",
            "ai_guide.intent.planner.step1": "Ouvrez l'onglet Plan.",
            "ai_guide.intent.planner.step2": "Verifiez le risque horaire et trouvez les intervalles plus favorables.",
            "ai_guide.intent.planner.step3": "Planifiez marche, sport ou ventilation pendant les creneaux surs.",
            "ai_guide.intent.planner.step4": "S'il n'y a pas de creneaux, reduisez l'activite exterieure et reverifiez.",
            "ai_guide.intent.notifications.title": "Comment configurer les notifications :",
            "ai_guide.intent.notifications.step1": "Ouvrez Parametres > Notifications.",
            "ai_guide.intent.notifications.step2": "Activez push et, si besoin, Morning Briefing.",
            "ai_guide.intent.notifications.step3": "Reglez seuil d'alerte et heures calmes selon votre routine.",
            "ai_guide.intent.notifications.step4": "Sauvegardez et confirmez la completion de la checklist.",
            "ai_guide.intent.symptoms.title": "Comment enregistrer les symptomes et utiliser les insights :",
            "ai_guide.intent.symptoms.step1": "Ouvrez Symptomes et enregistrez votre etat regulierement.",
            "ai_guide.intent.symptoms.step2": "Utilisez les boutons rapides pour un log immediate.",
            "ai_guide.intent.symptoms.step3": "Avec plus de donnees, ouvrez Insights pour voir vos patterns.",
            "ai_guide.intent.symptoms.step4": "Utilisez ces patterns avec meteo/air pour planifier la journee.",
            "ai_guide.intent.account.title": "Comment gerer compte, profil et confidentialite :",
            "ai_guide.intent.account.step1": "Dans Parametres, verifiez User ID, langue et profil par defaut.",
            "ai_guide.intent.account.step2": "Utilisez “Exporter mes donnees” pour une copie confidentialite.",
            "ai_guide.intent.account.step3": "Vous pouvez vous deconnecter ou supprimer le compte si necessaire.",
            "ai_guide.intent.account.step4": "Apres changements, synchronisez via le bouton en bas.",
            "ai_guide.intent.fallback.title": "Plan universel pour toute question :",
            "ai_guide.intent.fallback.step1": "Décrivez ce que vous voulez faire dans l'app.",
            "ai_guide.intent.fallback.step2": "Dites-moi sur quel écran vous êtes.",
            "ai_guide.intent.fallback.step3": "Je vous donnerai le chemin exact, bouton par bouton.",
            "ai_guide.intent.fallback.step4": "Si quelque chose échoue, envoyez le texte d'erreur et je vous aiderai.",
            "guide.title": "Guide HiAir",
            "guide.what_is_title": "Qu'est-ce que HiAir",
            "guide.problems_title": "Quels problemes l'application resout",
            "guide.for_whom_title": "Pour qui HiAir est utile",
            "guide.read_dashboard_title": "Comment lire l'ecran principal",
            "guide.risk_title": "Que signifie Risk Score",
            "guide.metrics_title": "Que signifient AQI, PM2.5, ozone, humidite et chaleur",
            "guide.hourly_title": "Comment utiliser la prevision horaire",
            "guide.safe_windows_title": "Que sont les creneaux surs",
            "guide.symptoms_title": "Comment utiliser le journal des symptomes",
            "guide.notifications_title": "Comment configurer les notifications",
            "guide.high_risk_title": "Que faire en cas de risque eleve",
            "guide.not_doctor_title": "Pourquoi HiAir ne remplace pas un medecin",
            "guide.faq_title": "FAQ",
            "settings.wearables.device_authorized": "accès autorisé",
            "settings.wearables.consent_inactive": "consentement inactif",
            "settings.wearables.connected": "connecté",
            "settings.wearables.disconnect": "Déconnecter",
            "settings.wearables.delete": "Supprimer les données health",
            "settings.wearables.delete_done": "Données health locales supprimées",
            "settings.wearables.connect": "Connecter Apple Health",
        ],
    ]
}

extension AppSession {
    func l(_ key: String) -> String {
        HiAirL10n.t(key, lang: preferredLanguage)
    }

    func lHealthKitError(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("wearable.health.error.generic|") {
            let detail = String(raw.dropFirst("wearable.health.error.generic|".count))
            return l("wearable.health.error.generic").replacingOccurrences(of: "%@", with: detail)
        }
        return l(raw)
    }
}
