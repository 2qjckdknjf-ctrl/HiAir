import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @State private var purchasingProductId: String?
    @State private var statusMessage = ""

    private var purchaseBusy: Bool {
        purchasingProductId != nil || subscriptionService.isPurchaseInProgress
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: HiAirSpacing.lg) {
                        HiAirBrandHeader(
                            title: session.l("paywall.title"),
                            subtitle: session.l("paywall.subtitle"),
                            showOrb: true,
                            orbSize: 56,
                            compact: false
                        )

                        comparisonCard
                        examplesCard
                        benefitsCard
                        catalogContent

                        Button(session.l("paywall.restore")) {
                            Task { await restore() }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                        .disabled(purchaseBusy)

                        Text(session.l("paywall.disclaimer"))
                            .font(HiAirTypography.caption)
                            .foregroundStyle(HiAirColors.Text.secondary)

                        HStack(spacing: HiAirSpacing.md) {
                            Link(session.l("paywall.terms"), destination: URL(string: "https://hiair.io/terms/")!)
                            Link(session.l("paywall.privacy"), destination: URL(string: "https://hiair.io/privacy/")!)
                        }
                        .font(HiAirTypography.caption)

                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(HiAirTypography.bodyMD)
                                .foregroundStyle(HiAirColors.Text.secondary)
                        }
                    }
                    .padding()
                }

                if purchaseBusy {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .allowsHitTesting(true)
                    ProgressView(session.l("paywall.purchasing"))
                        .padding()
                        .hiAirLiquidGlass(cornerRadius: HiAirRadius.md, variant: .regular)
                }
            }
            .navigationTitle(session.l("paywall.nav_title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(session.l("common.close")) { dismiss() }
                        .disabled(purchaseBusy)
                }
            }
            .onAppear {
                SubscriptionDiagnostics.log("paywall_appeared", resultType: "\(subscriptionService.catalogState)")
                subscriptionService.loadProducts()
            }
        }
        .hiAirPageBackground()
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
        .v2Card()
    }

    private var examplesCard: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            HiAirSectionHeader(title: session.l("paywall.examples.title"))
            exampleBlock(title: session.l("paywall.examples.ai.title"), body: session.l("paywall.examples.ai.body"))
            exampleBlock(title: session.l("paywall.examples.insights.title"), body: session.l("paywall.examples.insights.body"))
            exampleBlock(title: session.l("paywall.examples.forecast.title"), body: session.l("paywall.examples.forecast.body"))
        }
        .v2Card()
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            benefitRow(session.l("paywall.benefit.profiles"))
            benefitRow(session.l("paywall.benefit.forecast"))
            benefitRow(session.l("paywall.benefit.alerts"))
            benefitRow(session.l("paywall.benefit.export"))
            benefitRow(session.l("paywall.benefit.insights"))
        }
        .v2Card()
    }

    @ViewBuilder
    private var catalogContent: some View {
        switch subscriptionService.catalogState {
        case .idle, .loading:
            ProgressView(session.l("paywall.loading"))
                .frame(maxWidth: .infinity)
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
        .v2Card()
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
        .v2Card()
    }

    @ViewBuilder
    private func planOffer(product: Product, titleKey: String, subscribeKey: String) -> some View {
        let isPurchasing = purchasingProductId == product.id
        let disabledReason = subscribeDisabledReason(for: product)

        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.l(titleKey))
                        .font(HiAirTypography.titleMD)
                        .foregroundStyle(HiAirColors.Text.primary)
                    Text(product.description)
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirColors.Text.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirColors.Text.primary)
            }

            Button {
                handleSubscribeTap(product: product, disabledReason: disabledReason)
            } label: {
                Text(isPurchasing ? session.l("paywall.purchasing") : session.l(subscribeKey))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HiAirGradientButtonStyle())
            .disabled(disabledReason != nil)
        }
        .padding()
        .v2Card()
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
                accessToken: session.accessToken
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
