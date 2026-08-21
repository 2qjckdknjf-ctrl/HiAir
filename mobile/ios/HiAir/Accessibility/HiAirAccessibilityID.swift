import Foundation

/// Stable accessibility identifiers for UI tests and VoiceOver.
enum HiAirAccessibilityID {
    enum Auth {
        static let root = "auth.root"
        static let emailField = "auth.email"
        static let passwordField = "auth.password"
        static let logInButton = "auth.log_in"
        static let signUpButton = "auth.sign_up"
        static let errorBanner = "auth.error"
    }

    enum Onboarding {
        static let root = "onboarding.root"
        static let startButton = "onboarding.start"
        static let finishButton = "onboarding.finish"
    }

    enum Tabs {
        static let dashboard = "tab.dashboard"
        static let planner = "tab.planner"
        static let insights = "tab.insights"
        static let symptoms = "tab.symptoms"
        static let settings = "tab.settings"
    }

    enum Dashboard {
        static let root = "dashboard.root"
        static let createProfileCTA = "dashboard.create_profile"
        static let profileEnsureError = "dashboard.profile_ensure_error"
        static let locationRetry = "dashboard.location_retry"
        static let locationOpenSettings = "dashboard.location_open_settings"
        static let refresh = "dashboard.refresh"
        static let placeChip = "dashboard.place_chip"
    }

    enum Planner {
        static let root = "planner.root"
        static let createProfileCTA = "planner.create_profile"
        static let refresh = "planner.refresh"
        static let status = "planner.status"
    }

    enum Insights {
        static let root = "insights.root"
        static let createProfileCTA = "insights.create_profile"
        static let refresh = "insights.refresh"
    }

    enum Settings {
        static let root = "settings.root"
        static let logout = "settings.logout"
        static let openPaywall = "settings.open_paywall"
        static let language = "settings.language"
        static let restorePurchases = "settings.restore_purchases"
        static let manageSubscription = "settings.manage_subscription"
        static let supportEmail = "settings.support_email"
        static let deleteAccount = "settings.delete_account"
    }

    enum Paywall {
        static let root = "paywall.root"
        static let close = "paywall.close"
        static let purchase = "paywall.purchase"
        static let subscribeMonthly = "paywall.subscribe_monthly"
        static let subscribeYearly = "paywall.subscribe_yearly"
        static let lengthMonthly = "paywall.length_monthly"
        static let lengthYearly = "paywall.length_yearly"
        static let priceMonthly = "paywall.price_monthly"
        static let priceYearly = "paywall.price_yearly"
        static let restore = "paywall.restore"
        static let legalCopy = "paywall.legal_copy"
    }

    enum ProfileEnsure {
        static let loading = "profile_ensure.loading"
        static let error = "profile_ensure.error"
        static let locationAction = "profile_ensure.location_action"
    }
}
