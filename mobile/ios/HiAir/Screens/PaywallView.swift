import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var purchasingProductId: String?
    @State private var statusMessage = ""

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

                        if subscriptionService.isLoading && subscriptionService.products.isEmpty {
                            ProgressView(session.l("paywall.loading"))
                                .frame(maxWidth: .infinity)
                        } else {
                            planOffer(
                                productId: SubscriptionService.monthlyProductId,
                                titleKey: "paywall.plan_monthly",
                                subscribeKey: "paywall.subscribe_monthly"
                            )
                            planOffer(
                                productId: SubscriptionService.yearlyProductId,
                                titleKey: "paywall.plan_yearly",
                                subscribeKey: "paywall.subscribe_yearly"
                            )

                            if subscriptionService.products.isEmpty {
                                Text(subscriptionService.lastError ?? session.l("paywall.products_unavailable"))
                                    .font(AuroraTokens.Typography.bodyMD)
                                    .foregroundStyle(HiAirV2Theme.secondaryText)
                                Text(session.l("paywall.asc_hint"))
                                    .font(AuroraTokens.Typography.caption)
                                    .foregroundStyle(HiAirV2Theme.tertiaryText)
                                Button(session.l("paywall.retry")) {
                                    Task { await subscriptionService.loadProducts() }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }

                        Button(session.l("paywall.restore")) {
                            Task { await restore() }
                        }
                        .disabled(purchasingProductId != nil)

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

                if purchasingProductId != nil {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    ProgressView(session.l("paywall.purchasing"))
                        .padding()
                        .hiAirLiquidGlass(cornerRadius: HiAirRadius.md, variant: .regular)
                }
            }
            .navigationTitle(session.l("paywall.nav_title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(session.l("common.close")) { dismiss() }
                }
            }
            .task {
                await subscriptionService.loadProducts()
            }
        }
    }

    @ViewBuilder
    private func planOffer(productId: String, titleKey: String, subscribeKey: String) -> some View {
        let product = subscriptionService.products.first { $0.id == productId }
        let priceText = product?.displayPrice ?? session.l("paywall.price_pending")
        let isPurchasing = purchasingProductId == productId

        VStack(alignment: .leading, spacing: HiAirSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.l(titleKey))
                        .font(AuroraTokens.Typography.titleMD)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    if let product {
                        Text(product.description)
                            .font(AuroraTokens.Typography.caption)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                    }
                }
                Spacer()
                Text(priceText)
                    .font(AuroraTokens.Typography.titleMD)
                    .foregroundStyle(HiAirV2Theme.primaryText)
            }

            Button {
                Task { await purchase(productId: productId, product: product) }
            } label: {
                Text(isPurchasing ? session.l("paywall.purchasing") : session.l(subscribeKey))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HiAirGradientButtonStyle())
            .disabled(isPurchasing || purchasingProductId != nil)
        }
        .padding()
        .v2Card()
    }

    private func benefitRow(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(AuroraTokens.Typography.bodyMD)
            .foregroundStyle(HiAirV2Theme.primaryText)
    }

    private func purchase(productId: String, product: Product?) async {
        guard let product else {
            statusMessage = subscriptionService.lastError ?? session.l("paywall.products_unavailable")
            return
        }
        guard !session.userId.isEmpty, !session.accessToken.isEmpty else {
            statusMessage = session.l("paywall.auth_required")
            return
        }
        purchasingProductId = productId
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
        } catch let error as APIError {
            statusMessage = subscriptionService.userFacingMessage(for: error)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func restore() async {
        guard !session.userId.isEmpty, !session.accessToken.isEmpty else {
            statusMessage = session.l("paywall.auth_required")
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
        } catch let error as APIError {
            statusMessage = subscriptionService.userFacingMessage(for: error)
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
