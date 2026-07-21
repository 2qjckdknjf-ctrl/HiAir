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
                        Text(session.l("paywall.title"))
                            .font(AuroraTokens.Typography.displayLG)
                            .foregroundStyle(HiAirV2Theme.primaryText)

                        Text(session.l("paywall.subtitle"))
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.secondaryText)

                        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
                            benefitRow(session.l("paywall.benefit.profiles"))
                            benefitRow(session.l("paywall.benefit.forecast"))
                            benefitRow(session.l("paywall.benefit.alerts"))
                            benefitRow(session.l("paywall.benefit.export"))
                            benefitRow(session.l("paywall.benefit.insights"))
                        }
                        .padding()
                        .v2Card()

                        catalogContent

                        Button(session.l("paywall.restore")) {
                            Task { await restore() }
                        }
                        .disabled(purchaseBusy)

                        Text(session.l("paywall.disclaimer"))
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.secondaryText)

                        HStack(spacing: HiAirSpacing.md) {
                            Link(session.l("paywall.terms"), destination: URL(string: "https://hiair.io/terms/")!)
                            Link(session.l("paywall.privacy"), destination: URL(string: "https://hiair.io/privacy/")!)
                        }
                        .font(AuroraTokens.Typography.caption)

                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(AuroraTokens.Typography.bodyMD)
                                .foregroundStyle(HiAirV2Theme.secondaryText)
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
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            Text(session.l("paywall.catalog_help"))
                .font(AuroraTokens.Typography.caption)
                .foregroundStyle(HiAirV2Theme.tertiaryText)
            #if DEBUG
            Text(session.l("paywall.asc_hint"))
                .font(AuroraTokens.Typography.caption)
                .foregroundStyle(HiAirV2Theme.tertiaryText)
            #endif
            Button(session.l("paywall.retry")) {
                SubscriptionDiagnostics.log("products_retry_tapped")
                subscriptionService.loadProducts()
            }
            .buttonStyle(.borderedProminent)
            .disabled(purchaseBusy || subscriptionService.isLoading)
        }
    }

    private var failedCatalogBlock: some View {
        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            Text(subscriptionService.lastError ?? session.l("paywall.products_unavailable"))
                .font(AuroraTokens.Typography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)
            Text(session.l("paywall.catalog_help"))
                .font(AuroraTokens.Typography.caption)
                .foregroundStyle(HiAirV2Theme.tertiaryText)
            #if DEBUG
            Text(session.l("paywall.asc_hint"))
                .font(AuroraTokens.Typography.caption)
                .foregroundStyle(HiAirV2Theme.tertiaryText)
            #endif
            Button(session.l("paywall.retry")) {
                SubscriptionDiagnostics.log("products_retry_tapped")
                subscriptionService.loadProducts()
            }
            .buttonStyle(.borderedProminent)
            .disabled(purchaseBusy || subscriptionService.isLoading)
        }
    }

    @ViewBuilder
    private func planOffer(product: Product, titleKey: String, subscribeKey: String) -> some View {
        let isPurchasing = purchasingProductId == product.id
        let disabledReason = subscribeDisabledReason(for: product)

        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.l(titleKey))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Text(product.description)
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(AuroraTokens.Typography.titleMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
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
            .font(AuroraTokens.Typography.bodyMD)
            .foregroundStyle(HiAirV2Theme.primaryText)
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

        do {
            let status = try await subscriptionService.purchase(
                product,
                userId: session.userId,
                accessToken: session.accessToken
            )
            session.applyEntitlement(status.entitlement)
            if status.entitlement?.isPremium == true || session.isPremium {
                statusMessage = session.l("paywall.success")
                dismiss()
                return
            }
            await session.refreshEntitlement()
            if session.isPremium {
                statusMessage = session.l("paywall.success")
                dismiss()
            } else {
                statusMessage = session.l("paywall.verify_pending")
            }
        } catch SubscriptionServiceError.cancelled {
            statusMessage = session.l("paywall.purchase_cancelled")
        } catch SubscriptionServiceError.pending {
            statusMessage = session.l("paywall.purchase_pending")
        } catch SubscriptionServiceError.verificationFailed {
            statusMessage = session.l("paywall.verification_failed")
        } catch SubscriptionServiceError.purchaseInProgress {
            statusMessage = session.l("paywall.purchase_in_progress")
        } catch let error as APIError {
            statusMessage = subscriptionService.userFacingMessage(for: error, language: session.preferredLanguage)
        } catch {
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
            statusMessage = session.l("paywall.restore_success")
            if status.entitlement?.isPremium == true || session.isPremium {
                dismiss()
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
