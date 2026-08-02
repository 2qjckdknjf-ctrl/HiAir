import XCTest
@testable import HiAir

/// TF167: UI must not show account "connected" when sync is blocked by consent_missing.
@MainActor
final class WearableConsentUIStateTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!
    private var service: HealthKitService!

    override func setUp() async throws {
        defaultsSuiteName = "hiair.tests.wearable.consent.ui.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        service = HealthKitService(defaults: defaults)
        service.prepareForUnitTests()
    }

    override func tearDown() async throws {
        if let name = defaultsSuiteName {
            defaults?.removePersistentDomain(forName: name)
        }
        service = nil
        defaults = nil
        defaultsSuiteName = nil
    }

    private func localizeRU(_ key: String) -> String {
        HiAirL10n.t(key, lang: "ru")
    }

    private func localizeEN(_ key: String) -> String {
        HiAirL10n.t(key, lang: "en")
    }

    private func status(
        state: WearableConnectionState,
        consentActive: Bool,
        durable: Bool,
        systemAuth: Bool,
        lang: String = "ru"
    ) -> String {
        WearableStatusPresentation.statusLabel(
            connectionState: state,
            consentActive: consentActive,
            hasDurableConsent: durable,
            hasSystemAuthorization: systemAuth,
            localize: { HiAirL10n.t($0, lang: lang) }
        )
    }

    func testOSAuthorizedConsentMissingIsNotAccountConnected() {
        service.seedDurableConsentMarkersForTests(userId: "user-a", authorized: true, consented: false)
        service.bindAccount(userId: "user-a")
        XCTAssertEqual(service.connectionState, .systemAuthorized)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))

        let label = status(
            state: service.connectionState,
            consentActive: false,
            durable: false,
            systemAuth: true
        )
        XCTAssertFalse(label.contains(localizeRU("settings.wearables.connected")))
        XCTAssertTrue(label.contains(localizeRU("settings.wearables.device_authorized")))
        XCTAssertFalse(WearableStatusPresentation.isAccountSyncConnected(
            connectionState: .connected,
            hasDurableConsent: false,
            consentActive: false
        ))
    }

    func testStaleConnectedStateWithoutDurableConsentDemotesAndIsNotConnectedUI() {
        service.seedDurableConsentMarkersForTests(userId: "user-a", authorized: true, consented: false)
        service.bindAccount(userId: "user-a")
        service.reportConnectionState(.connected) // stale TF167 shape
        XCTAssertEqual(service.connectionState, .connected)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))

        let demoted = service.demoteConnectedWithoutDurableConsent(for: "user-a")
        XCTAssertEqual(demoted, .systemAuthorized)
        XCTAssertEqual(service.connectionState, .systemAuthorized)

        let label = status(
            state: .connected, // even if caller passes stale enum
            consentActive: false,
            durable: false,
            systemAuth: true
        )
        XCTAssertFalse(label.contains(localizeRU("settings.wearables.connected")))
        XCTAssertTrue(label.contains(localizeRU("settings.wearables.device_authorized")))
    }

    func testInactiveConsentClearedAndUINotConnected() {
        service.seedDurableConsentMarkersForTests(userId: "user-a", authorized: true, consented: true)
        service.bindAccount(userId: "user-a")
        XCTAssertEqual(service.connectionState, .connected)

        service.reconcileServerConsent(userId: "user-a", isActive: false)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        XCTAssertEqual(service.connectionState, .systemAuthorized)

        let label = status(
            state: service.connectionState,
            consentActive: false,
            durable: false,
            systemAuth: true
        )
        XCTAssertFalse(label.contains(localizeRU("settings.wearables.connected")))
    }

    func testDurableInactiveConsentShowsConsentInactiveNotConnected() {
        let labelRU = status(
            state: .systemAuthorized,
            consentActive: false,
            durable: true,
            systemAuth: true,
            lang: "ru"
        )
        XCTAssertTrue(labelRU.contains(localizeRU("settings.wearables.consent_inactive")))
        XCTAssertFalse(labelRU.contains(localizeRU("settings.wearables.connected")))
        XCTAssertFalse(labelRU.contains(localizeRU("settings.wearables.device_authorized")))

        let labelEN = status(
            state: .connected, // stale enum still must not say connected
            consentActive: false,
            durable: true,
            systemAuth: true,
            lang: "en"
        )
        XCTAssertTrue(labelEN.contains(localizeEN("settings.wearables.consent_inactive")))
        XCTAssertFalse(labelEN.contains(localizeEN("settings.wearables.connected")))
    }

    func testStaleAsyncRefreshDoesNotOverwriteAfterAccountSwitch() async {
        UITestMockAPIProtocol.isEnabled = true
        UITestMockAPIProtocol.reset()
        UITestMockAPIProtocol.responseDelayNanoseconds = 250_000_000
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/v1/wearables/today",
            response: .json(
                200,
                object: [
                    "consent": [
                        "id": "c1",
                        "userId": "user-a",
                        "platform": "ios",
                        "source": "apple_health",
                        "stepsEnabled": true,
                        "heartRateEnabled": true,
                        "restingHeartRateEnabled": true,
                        "isActive": true,
                    ],
                    "dailySummary": NSNull(),
                    "personalLoad": NSNull(),
                ]
            )
        )
        defer {
            UITestMockAPIProtocol.responseDelayNanoseconds = 0
            UITestMockAPIProtocol.isEnabled = false
            UITestMockAPIProtocol.reset()
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UITestMockAPIProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = APIClient(baseURL: URL(string: "https://uitest.hiair.invalid")!, session: session)
        let vm = SettingsViewModel(apiClient: client)
        vm.preferredLanguage = "ru"
        vm.userId = "user-a"
        vm.accessToken = "tok-a"

        service.seedDurableConsentMarkersForTests(userId: "user-a", authorized: true, consented: true)
        service.bindAccount(userId: "user-a")

        let refresh = Task { await vm.refreshWearableStatus() }
        try? await Task.sleep(nanoseconds: 40_000_000)
        vm.userId = "user-b"
        vm.accessToken = "tok-b"
        vm.wearableStatus = "Apple Health: switched"
        await refresh.value
        XCTAssertEqual(vm.wearableStatus, "Apple Health: switched")
    }

    func testActiveConsentCurrentUserBindingIsConnected() {
        service.seedDurableConsentMarkersForTests(userId: "user-a", authorized: true, consented: true)
        service.bindAccount(userId: "user-a")
        XCTAssertEqual(service.connectionState, .connected)
        XCTAssertTrue(
            WearableStatusPresentation.isAccountSyncConnected(
                connectionState: .connected,
                hasDurableConsent: true,
                consentActive: true
            )
        )
        let label = status(
            state: .connected,
            consentActive: true,
            durable: true,
            systemAuth: true
        )
        XCTAssertTrue(label.contains(localizeRU("settings.wearables.connected")))
        XCTAssertEqual(
            status(state: .connected, consentActive: true, durable: true, systemAuth: true, lang: "en"),
            "Apple Health: connected"
        )
    }

    func testBindingOfOtherUserDoesNotShowConnectedForCurrentUser() {
        service.seedDurableConsentMarkersForTests(userId: "user-b", authorized: true, consented: true)
        service.bindAccount(userId: "user-b")
        XCTAssertEqual(service.connectionState, .connected)

        service.clearAccountSession()
        service.bindAccount(userId: "user-a")
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        XCTAssertNotEqual(service.connectionState, .connected)

        let label = status(
            state: service.connectionState,
            consentActive: false,
            durable: false,
            systemAuth: service.hasSystemAuthorization(for: "user-a")
        )
        XCTAssertFalse(label.contains(localizeRU("settings.wearables.connected")))
    }

    func testAccountSwitchRetainsOSAuthWithoutRebind() {
        service.seedDurableConsentMarkersForTests(userId: "user-a", authorized: true, consented: true)
        service.bindAccount(userId: "user-a")
        XCTAssertEqual(service.connectionState, .connected)

        service.clearAccountSession()
        // B has OS sheet completed but no durable consent.
        service.seedDurableConsentMarkersForTests(userId: "user-b", authorized: true, consented: false)
        service.bindAccount(userId: "user-b")
        XCTAssertTrue(service.hasSystemAuthorization(for: "user-b"))
        XCTAssertFalse(service.hasDurableConsent(for: "user-b"))
        XCTAssertEqual(service.connectionState, .systemAuthorized)
        XCTAssertNotEqual(service.connectionState, .connected)

        service.startBackgroundHealthSync(userId: "user-b", accessToken: "tok", profileId: nil)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        XCTAssertNil(service.lastSyncAt)
    }

    func testLogoutClearsAccountBoundPresentation() {
        service.seedDurableConsentMarkersForTests(userId: "user-a", authorized: true, consented: true)
        service.bindAccount(userId: "user-a")
        service.clearAccountSession()
        XCTAssertEqual(service.connectionState, .notConnected)
        XCTAssertTrue(service.boundUserId.isEmpty)
        // OS markers retained for restore; presentation is not connected.
        XCTAssertTrue(service.hasSystemAuthorization(for: "user-a"))
        XCTAssertTrue(service.hasDurableConsent(for: "user-a"))
    }

    func testHealthSyncBlockedConsentMissingAgreesWithUINotConnected() async {
        service.resetTestHooks()
        service.seedDurableConsentMarkersForTests(userId: "user-a", authorized: true, consented: false)
        service.bindAccount(userId: "user-a")
        service.reportConnectionState(.connected) // stale
        _ = service.demoteConnectedWithoutDurableConsent(for: "user-a")

        service.startBackgroundHealthSync(userId: "user-a", accessToken: "tok", profileId: nil)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        XCTAssertNotEqual(service.connectionState, .connected)

        let label = status(
            state: service.connectionState,
            consentActive: false,
            durable: false,
            systemAuth: true
        )
        XCTAssertFalse(label.contains(localizeRU("settings.wearables.connected")))
        XCTAssertFalse(label.contains(localizeEN("settings.wearables.connected")))
    }

    func testDisconnectCopyIsNotRemoteDeleteClaim() {
        let disconnectRU = localizeRU("settings.wearables.disconnect")
        let disconnectEN = localizeEN("settings.wearables.disconnect")
        let deleteRU = localizeRU("settings.wearables.delete")
        let deleteEN = localizeEN("settings.wearables.delete")
        XCTAssertEqual(disconnectRU, "Отключить")
        XCTAssertEqual(disconnectEN, "Disconnect")
        XCTAssertNotEqual(disconnectRU, deleteRU)
        XCTAssertNotEqual(disconnectEN, deleteEN)
        XCTAssertFalse(disconnectRU.lowercased().contains("удалить"))
        XCTAssertFalse(disconnectEN.lowercased().contains("delete"))
        XCTAssertTrue(deleteRU.lowercased().contains("удалить") || deleteRU.lowercased().contains("health"))
        XCTAssertTrue(deleteEN.lowercased().contains("delete"))
    }

    func testDeleteHealthDataRemainsSeparateExplicitAction() {
        XCTAssertNotEqual(
            localizeRU("settings.wearables.disconnect"),
            localizeRU("settings.wearables.delete")
        )
        XCTAssertNotEqual(
            localizeEN("settings.wearables.disconnect"),
            localizeEN("settings.wearables.delete")
        )
        XCTAssertEqual(localizeRU("settings.wearables.delete"), "Удалить health-данные")
        XCTAssertEqual(localizeEN("settings.wearables.delete"), "Delete health data")
    }

    func testAActiveLogoutBLoginNoRebindAReturn() {
        // A active
        service.seedDurableConsentMarkersForTests(userId: "user-a", authorized: true, consented: true)
        service.bindAccount(userId: "user-a")
        XCTAssertEqual(service.connectionState, .connected)

        // logout
        service.clearAccountSession()
        XCTAssertEqual(service.connectionState, .notConnected)

        // B login with OS auth retained, no consent
        service.seedDurableConsentMarkersForTests(userId: "user-b", authorized: true, consented: false)
        service.bindAccount(userId: "user-b")
        XCTAssertEqual(service.connectionState, .systemAuthorized)
        XCTAssertFalse(
            WearableStatusPresentation.isAccountSyncConnected(
                connectionState: service.connectionState,
                hasDurableConsent: false,
                consentActive: false
            )
        )

        // A return
        service.clearAccountSession()
        service.bindAccount(userId: "user-a")
        XCTAssertEqual(service.boundUserId, "user-a")
        XCTAssertEqual(service.connectionState, .connected)
        XCTAssertTrue(service.hasDurableConsent(for: "user-a"))
        XCTAssertFalse(service.hasDurableConsent(for: "user-b"))
    }

    func testRefreshAuthorizationDoesNotKeepStaleConnectedWithoutConsent() {
        service.seedDurableConsentMarkersForTests(userId: "user-a", authorized: true, consented: false)
        service.bindAccount(userId: "user-a")
        service.reportConnectionState(.connected)
        let refreshed = service.refreshAuthorizationState()
        XCTAssertEqual(refreshed, .systemAuthorized)
        XCTAssertEqual(service.connectionState, .systemAuthorized)
    }

    func testSettingsViewModelLabelMatchesPresentationHelper() {
        let vm = SettingsViewModel()
        vm.preferredLanguage = "ru"
        let label = vm.wearableStatusLabel(
            for: .connected,
            consentActive: false,
            hasDurableConsent: false,
            hasSystemAuthorization: true
        )
        XCTAssertFalse(label.contains("подключено"))
        XCTAssertTrue(label.contains("доступ разрешён"))
    }
}
