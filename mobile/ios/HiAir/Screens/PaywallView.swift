import SafariServices
import StoreKit
import SwiftUI

struct PaywallView: View {
    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                PaywallPurchaseEnvironment { perform in
                    PaywallContent(performPurchase: perform)
                }
            } else {
                PaywallContent(performPurchase: { product, options in
                    try await product.purchase(options: options)
                })
            }
        }
    }
}

@available(iOS 17.0, *)
private struct PaywallPurchaseEnvironment<Content: View>: View {
    @Environment(\.purchase) private var purchase
    let content: (@escaping SubscriptionService.StoreKitPurchase) -> Content

    init(content: @escaping (@escaping SubscriptionService.StoreKitPurchase) -> Content) {
        self.content = content
    }

    var body: some View {
        content { product, options in
            // StoreKit Testing + SKTestSession pairs reliably with Product.purchase(options:).
            // Production iPad fullScreenCover uses SwiftUI PurchaseAction first.
            if UITestBootstrap.isUITesting {
                return try await product.purchase(options: options)
            }
            do {
                return try await purchase(product, options: options)
            } catch {
                return try await SubscriptionService.fallbackStoreKitPurchase(product, options: options)
            }
        }
    }
}

private struct PaywallContent: View {
    let performPurchase: SubscriptionService.StoreKitPurchase
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @State private var purchasingProductId: String?
    @State private var statusMessage = ""
    @State private var safariURL: URL?

    private var purchaseBusy: Bool {
        purchasingProductId != nil || subscriptionService.isPurchaseInProgress
    }

    var body: some View {
        ZStack {
            HiAirAtmosphericBackground()
            HiAirAdaptiveLayout { width, _ in
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: HiAirSpacing.lg) {
                            HiAirBrandHeader(
                                title: session.l("paywall.title"),
                                subtitle: session.l("paywall.subtitle"),
                                showOrb: true,
                                orbSize: 56,
                                compact: false
                            )

                            benefitsCard
                            catalogContent

                            Button(session.l("paywall.restore")) {
                                Task { await restore() }
                            }
                            .buttonStyle(HiAirSecondaryButtonStyle())
                            .disabled(purchaseBusy)
                            .accessibilityIdentifier(HiAirAccessibilityID.Paywall.restore)

                            Text(session.l("paywall.legal_auto_renew"))
                                .font(HiAirTypography.caption)
                                .foregroundStyle(HiAirColors.Text.secondary)
                                .accessibilityIdentifier(HiAirAccessibilityID.Paywall.legalCopy)

                            HStack(spacing: HiAirSpacing.md) {
                                policyButton(session.l("paywall.terms"), url: termsURL)
                                policyButton(session.l("paywall.privacy"), url: privacyURL)
                            }

                            Button(session.l("settings.manage_subscription")) {
                                Task { await subscriptionService.showManageSubscriptions() }
                            }
                            .font(HiAirTypography.bodyMD)
                            .foregroundStyle(HiAirColors.Spectrum.cyan)

                            Text(session.l("paywall.disclaimer"))
                                .font(HiAirTypography.caption)
                                .foregroundStyle(HiAirColors.Text.secondary)

                            if !statusMessage.isEmpty {
                                Text(statusMessage)
                                    .font(HiAirTypography.bodyMD)
                                    .foregroundStyle(HiAirColors.Text.secondary)
                            }
                        }
                        .hiAirContentWidth(for: width)
                        .hiAirScreenPadding(for: width)
                        .padding(.bottom, HiAirSpacing.xl)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .navigationTitle(session.l("paywall.nav_title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(session.l("common.close")) { dismiss() }
                                .font(HiAirTypography.bodyMD.weight(.semibold))
                                .foregroundStyle(HiAirColors.Spectrum.cyan)
                                .disabled(purchaseBusy)
                                .accessibilityIdentifier(HiAirAccessibilityID.Paywall.close)
                        }
                    }
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbar(.visible, for: .navigationBar)
                }
            }
            .onAppear {
                SubscriptionDiagnostics.log("paywall_appeared", resultType: "\(subscriptionService.catalogState)")
                subscriptionService.loadProducts()
            }
            .onChange(of: session.isPremium) { isPremium in
                if isPremium { dismiss() }
            }
            .sheet(isPresented: Binding(
                get: { safariURL != nil },
                set: { if !$0 { safariURL = nil } }
            )) {
                if let safariURL {
                    PaywallSafariView(url: safariURL)
                        .ignoresSafeArea()
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(purchaseBusy)
        .accessibilityIdentifier(HiAirAccessibilityID.Paywall.root)
    }

    private var termsURL: URL { URL(string: "https://hiair.io/terms/")! }
    private var privacyURL: URL { URL(string: "https://hiair.io/privacy/")! }

    private var requiredSubscriptionFacts: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.md) {
            HiAirSectionHeader(title: session.l("paywall.required_info"))
            subscriptionFactRow(
                product: subscriptionService.monthlyProduct,
                fallbackTitle: session.l("paywall.offer_title_monthly"),
                length: session.l("paywall.length_month")
            )
            subscriptionFactRow(
                product: subscriptionService.yearlyProduct,
                fallbackTitle: session.l("paywall.offer_title_yearly"),
                length: session.l("paywall.length_year")
            )
            Text(session.l("paywall.service_period"))
                .font(HiAirTypography.caption)
                .foregroundStyle(HiAirColors.Text.secondary)
            HStack(spacing: HiAirSpacing.md) {
                policyButton(session.l("paywall.terms"), url: termsURL)
                policyButton(session.l("paywall.privacy"), url: privacyURL)
            }
        }
        .padding(HiAirSpacing.md)
        .hiAirGlassSurface(prominence: .standard, glow: HiAirColors.Spectrum.cyan)
        .accessibilityIdentifier(HiAirAccessibilityID.Paywall.legalCopy)
    }

    private func policyButton(_ title: String, url: URL) -> some View {
        Button(title) { safariURL = url }
            .font(HiAirTypography.bodyMD)
            .foregroundStyle(HiAirColors.Spectrum.cyan)
            .accessibilityIdentifier(url == termsURL ? HiAirAccessibilityID.Paywall.terms : HiAirAccessibilityID.Paywall.privacy)
    }

    private func subscriptionFactRow(product: Product?, fallbackTitle: String, length: String) -> some View {
        // Always use ASC-style offer titles so monthly/yearly stay distinct even when
        // StoreKit displayName is the shared group name "HiAir Premium".
        let price = resolvedDisplayPrice(product, yearly: length == session.l("paywall.length_year"))
        return VStack(alignment: .leading, spacing: 4) {
            Text(fallbackTitle)
                .font(HiAirTypography.titleMD)
                .foregroundStyle(HiAirColors.Text.primary)
            Text(length)
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.secondary)
            Text(price)
                .font(HiAirTypography.titleMD)
                .foregroundStyle(HiAirColors.Text.primary)
            if let perMonth = yearlyPerMonthPrice(product) {
                Text(String(format: session.l("paywall.price_per_month"), perMonth))
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirColors.Text.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func resolvedDisplayPrice(_ product: Product?, yearly: Bool) -> String {
        if let product, !product.displayPrice.isEmpty {
            return product.displayPrice
        }
        if UITestBootstrap.isStoreShots {
            return yearly ? "$39.99" : "$4.99"
        }
        return session.l("paywall.price_pending")
    }

    private func yearlyPerMonthPrice(_ product: Product?) -> String? {
        guard let product, product.id == StoreProductIDs.yearly else { return nil }
        guard let period = product.subscription?.subscriptionPeriod, period.unit == .year else { return nil }
        let monthly = product.price / Decimal(12)
        return monthly.formatted(product.priceFormatStyle)
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            HiAirSectionHeader(title: session.l("paywall.compare.title"))
            compareRow(free: true, text: session.l("paywall.compare.free.risk"))
            compareRow(free: true, text: session.l("paywall.compare.free.health"))
            compareRow(free: false, text: session.l("paywall.compare.premium.planner"))
            compareRow(free: false, text: session.l("paywall.compare.premium.insights"))
            compareRow(free: false, text: session.l("paywall.compare.premium.ai"))
            compareRow(free: false, text: session.l("paywall.compare.premium.reports"))
        }
        .padding(HiAirSpacing.md)
        .hiAirGlassSurface(prominence: .passive)
    }

    private var examplesCard: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            HiAirSectionHeader(title: session.l("paywall.examples.title"))
            exampleBlock(title: session.l("paywall.examples.ai.title"), body: session.l("paywall.examples.ai.body"))
            exampleBlock(title: session.l("paywall.examples.insights.title"), body: session.l("paywall.examples.insights.body"))
            exampleBlock(title: session.l("paywall.examples.forecast.title"), body: session.l("paywall.examples.forecast.body"))
        }
        .padding(HiAirSpacing.md)
        .hiAirGlassSurface(prominence: .passive)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            benefitRow(session.l("paywall.benefit.profiles"))
            benefitRow(session.l("paywall.benefit.forecast"))
            benefitRow(session.l("paywall.benefit.alerts"))
            benefitRow(session.l("paywall.benefit.export"))
            benefitRow(session.l("paywall.benefit.insights"))
        }
        .padding(HiAirSpacing.md)
        .hiAirGlassSurface(prominence: .passive)
    }

    @ViewBuilder
    private var catalogContent: some View {
        switch subscriptionService.catalogState {
        case .idle, .loading:
            // Fact card already shows title/length/price; avoid a second loading spinner on iPad.
            EmptyView()
        case .loaded, .purchasing:
            if let monthly = subscriptionService.monthlyProduct {
                planOffer(product: monthly, titleKey: "paywall.plan_monthly", subscribeKey: "paywall.subscribe_monthly")
            }
            if let yearly = subscriptionService.yearlyProduct {
                planOffer(product: yearly, titleKey: "paywall.plan_yearly", subscribeKey: "paywall.subscribe_yearly")
            }
            if subscriptionService.products.isEmpty {
                emptyCatalogBlock
            }
        case .empty:
            emptyCatalogBlock
        case .failed:
            failedCatalogBlock
        }
    }

    private var emptyCatalogBlock: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            Text(session.l("paywall.products_empty"))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.secondary)
            Text(session.l("paywall.catalog_help"))
                .font(HiAirTypography.caption)
                .foregroundStyle(HiAirColors.Text.tertiary)
            Button(session.l("paywall.retry")) {
                SubscriptionDiagnostics.log("products_retry_tapped")
                subscriptionService.loadProducts()
            }
            .buttonStyle(HiAirGradientButtonStyle())
            .disabled(purchaseBusy || subscriptionService.isLoading)
        }
        .padding(HiAirSpacing.md)
        .hiAirGlassSurface(prominence: .passive)
    }

    private var failedCatalogBlock: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            Text(subscriptionService.lastError ?? session.l("paywall.products_unavailable"))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.secondary)
            Text(session.l("paywall.catalog_help"))
                .font(HiAirTypography.caption)
                .foregroundStyle(HiAirColors.Text.tertiary)
            Button(session.l("paywall.retry")) {
                SubscriptionDiagnostics.log("products_retry_tapped")
                subscriptionService.loadProducts()
            }
            .buttonStyle(HiAirGradientButtonStyle())
            .disabled(purchaseBusy || subscriptionService.isLoading)
        }
        .padding(HiAirSpacing.md)
        .hiAirGlassSurface(prominence: .passive)
    }

    @ViewBuilder
    private func planOffer(product: Product, titleKey: String, subscribeKey: String) -> some View {
        let isPurchasing = purchasingProductId == product.id
        let disabledReason = subscribeDisabledReason(for: product)
        let yearly = product.id == StoreProductIDs.yearly

        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            Text(planDisplayTitle(product: product, titleKey: titleKey))
                .font(HiAirTypography.titleMD)
                .foregroundStyle(HiAirColors.Text.primary)
            Text(session.l(yearly ? "paywall.length_year" : "paywall.length_month"))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.secondary)
                .accessibilityIdentifier(
                    yearly
                        ? HiAirAccessibilityID.Paywall.lengthYearly
                        : HiAirAccessibilityID.Paywall.lengthMonthly
                )
            Text(product.displayPrice)
                .font(HiAirTypography.titleMD)
                .foregroundStyle(HiAirColors.Text.primary)
                .accessibilityIdentifier(
                    yearly
                        ? HiAirAccessibilityID.Paywall.priceYearly
                        : HiAirAccessibilityID.Paywall.priceMonthly
                )
            if let perMonth = yearlyPerMonthPrice(product) {
                Text(String(format: session.l("paywall.price_per_month"), perMonth))
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirColors.Text.secondary)
            }

            Button {
                handleSubscribeTap(product: product, disabledReason: disabledReason)
            } label: {
                Text(isPurchasing ? session.l("paywall.purchasing") : session.l(subscribeKey))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HiAirGradientButtonStyle())
            .disabled(disabledReason != nil)
            .accessibilityIdentifier(
                yearly
                    ? HiAirAccessibilityID.Paywall.subscribeYearly
                    : HiAirAccessibilityID.Paywall.subscribeMonthly
            )
        }
        .padding()
        .hiAirGlassSurface(prominence: .standard, glow: HiAirColors.Spectrum.cyan)
    }

    private func compareRow(free: Bool, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(free ? session.l("paywall.compare.badge.free") : session.l("paywall.compare.badge.premium"))
                .font(HiAirTypography.caption)
                .foregroundStyle(free ? HiAirColors.Text.secondary : HiAirColors.Brand.orbCyan)
                .frame(width: 72, alignment: .leading)
            Text(text)
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.primary)
            Spacer(minLength: 0)
        }
    }

    private func exampleBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.primary)
            Text(body)
                .font(HiAirTypography.caption)
                .foregroundStyle(HiAirColors.Text.secondary)
        }
        .padding(HiAirSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hiAirTileSurface()
    }

    private func planDisplayTitle(product: Product, titleKey: String) -> String {
        let fallback = session.l(titleKey)
        let name = product.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return fallback }
        let lower = name.lowercased()
        let distinguishesPeriod =
            lower.contains("month") || lower.contains("year")
            || lower.contains("месяц") || lower.contains("год")
            || lower.contains("mensual") || lower.contains("anual")
            || lower.contains("mensile") || lower.contains("annuale")
            || lower.contains("mensuel") || lower.contains("annuel")
        return distinguishesPeriod ? name : fallback
    }

    private func subscribeDisabledReason(for product: Product) -> String? {
        if session.isPremium { return "entitlement_active" }
        if subscriptionService.isLoading { return "loading" }
        if purchaseBusy { return "purchase_in_progress" }
        if product.displayPrice.isEmpty { return "no_product" }
        return nil
    }

    private func handleSubscribeTap(product: Product, disabledReason: String?) {
        if let disabledReason {
            SubscriptionDiagnostics.log(
                "subscribe_blocked_\(disabledReason)",
                productId: product.id
            )
            return
        }
        SubscriptionDiagnostics.log("subscribe_button_tapped", productId: product.id)
        Task { await purchase(product: product) }
    }

    private func benefitRow(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(HiAirTypography.bodyMD)
            .foregroundStyle(HiAirColors.Text.primary)
    }

    private func purchase(product: Product) async {
        #if DEBUG
        if UITestBootstrap.isUITesting,
           ProcessInfo.processInfo.environment["UITEST_IAP_FORCE_SUCCESS"] == "1" {
            let optimistic = UserEntitlementResponse(
                userId: session.userId,
                plan: product.id.contains("yearly") ? "yearly" : "monthly",
                isPremium: true,
                maxProfiles: 5,
                extendedForecastEnabled: true,
                customAlertsEnabled: true,
                exportReportsEnabled: true,
                advancedInsightsEnabled: true
            )
            session.beginPremiumActivation(optimistic: optimistic)
            NotificationCenter.default.post(
                name: .subscriptionEntitlementDidUpdate,
                object: optimistic,
                userInfo: ["activationPending": false]
            )
            statusMessage = session.l("paywall.success")
            dismiss()
            return
        }
        #endif
        guard !session.userId.isEmpty, !session.accessToken.isEmpty else {
            statusMessage = session.l("paywall.auth_required")
            return
        }
        guard purchasingProductId == nil, !subscriptionService.isPurchaseInProgress else {
            SubscriptionDiagnostics.log("subscribe_blocked_purchase_in_progress", productId: product.id)
            statusMessage = session.l("paywall.purchase_in_progress")
            return
        }

        purchasingProductId = product.id
        defer { purchasingProductId = nil }
        statusMessage = session.l("paywall.purchasing")
        RuntimePerformanceProbe.begin("premium_unlock")

        do {
            let status = try await subscriptionService.purchase(
                product,
                userId: session.userId,
                accessToken: session.accessToken,
                performPurchase: performPurchase
            )
            session.applyEntitlement(status.entitlement)
            if status.entitlement?.isPremium == true || session.isPremium {
                RuntimePerformanceProbe.end("premium_unlock", success: true)
                statusMessage = session.l("paywall.success")
                dismiss()
                return
            }
            // Bounded fast /me retries (not 8s foreground debounce).
            statusMessage = session.l("paywall.verify_pending")
            for _ in 0..<4 {
                try? await Task.sleep(nanoseconds: 400_000_000)
                await session.refreshEntitlement()
                if session.isPremium {
                    RuntimePerformanceProbe.end("premium_unlock", success: true)
                    statusMessage = session.l("paywall.success")
                    dismiss()
                    return
                }
            }
            RuntimePerformanceProbe.end("premium_unlock", success: false, errorCode: "entitlement_lag")
            statusMessage = session.l("paywall.verify_pending")
        } catch SubscriptionServiceError.cancelled {
            RuntimePerformanceProbe.end("premium_unlock", success: false, errorCode: "cancelled")
            statusMessage = session.l("paywall.purchase_cancelled")
        } catch SubscriptionServiceError.pending {
            RuntimePerformanceProbe.end("premium_unlock", success: false, errorCode: "pending")
            statusMessage = session.l("paywall.purchase_pending")
        } catch SubscriptionServiceError.verificationFailed {
            RuntimePerformanceProbe.end("premium_unlock", success: false, errorCode: "verify_failed")
            statusMessage = session.l("paywall.verification_failed")
        } catch SubscriptionServiceError.purchaseInProgress {
            RuntimePerformanceProbe.end("premium_unlock", success: false, errorCode: "in_progress")
            statusMessage = session.l("paywall.purchase_in_progress")
        } catch SubscriptionServiceError.purchaseSceneUnavailable {
            RuntimePerformanceProbe.end("premium_unlock", success: false, errorCode: "scene_unavailable")
            statusMessage = session.l("paywall.generic_error")
        } catch let error as APIError {
            RuntimePerformanceProbe.end("premium_unlock", success: false, errorCode: "api")
            statusMessage = subscriptionService.userFacingMessage(for: error, language: session.preferredLanguage)
        } catch {
            RuntimePerformanceProbe.end("premium_unlock", success: false, errorCode: "generic")
            statusMessage = session.l("paywall.generic_error")
        }
    }

    private func restore() async {
        guard !session.userId.isEmpty, !session.accessToken.isEmpty else {
            statusMessage = session.l("paywall.auth_required")
            return
        }
        guard !purchaseBusy else {
            statusMessage = session.l("paywall.purchase_in_progress")
            return
        }
        purchasingProductId = "restore"
        defer { purchasingProductId = nil }
        statusMessage = session.l("paywall.restoring")
        do {
            let status = try await subscriptionService.restorePurchases(
                userId: session.userId,
                accessToken: session.accessToken
            )
            session.applyEntitlement(status.entitlement)
            if status.entitlement?.isPremium == true || session.isPremium {
                statusMessage = session.l("paywall.restore_success")
                dismiss()
            } else {
                statusMessage = session.l("paywall.restore_nothing")
            }
        } catch SubscriptionServiceError.purchaseInProgress {
            statusMessage = session.l("paywall.purchase_in_progress")
        } catch let error as APIError {
            statusMessage = subscriptionService.userFacingMessage(for: error, language: session.preferredLanguage)
        } catch {
            statusMessage = session.l("paywall.generic_error")
        }
    }
}

private struct PaywallSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
