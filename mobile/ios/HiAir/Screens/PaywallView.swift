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
                    } else if subscriptionService.products.isEmpty {
                        Text(subscriptionService.lastError ?? session.l("paywall.products_unavailable"))
                            .font(AuroraTokens.Typography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.secondaryText)
                        Button(session.l("paywall.retry")) {
                            Task { await subscriptionService.loadProducts() }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        ForEach(subscriptionService.products, id: \.id) { product in
                            planCard(product: product)
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
                        Link(session.l("paywall.terms"), destination: URL(string: "https://hiair.app/terms")!)
                        Link(session.l("paywall.privacy"), destination: URL(string: "https://hiair.app/privacy")!)
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
    private func planCard(product: Product) -> some View {
        Button {
            Task { await purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(AuroraTokens.Typography.titleMD)
                    Text(product.description)
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(AuroraTokens.Typography.titleMD)
            }
            .padding()
            .v2Card()
        }
        .disabled(purchasingProductId != nil)
    }

    private func benefitRow(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(AuroraTokens.Typography.bodyMD)
            .foregroundStyle(HiAirV2Theme.primaryText)
    }

    private func purchase(_ product: Product) async {
        guard !session.userId.isEmpty, !session.accessToken.isEmpty else { return }
        purchasingProductId = product.id
        defer { purchasingProductId = nil }
        do {
            let status = try await subscriptionService.purchase(
                product,
                userId: session.userId,
                accessToken: session.accessToken
            )
            session.applyEntitlement(status.entitlement)
            statusMessage = session.l("paywall.success")
            dismiss()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func restore() async {
        guard !session.userId.isEmpty, !session.accessToken.isEmpty else { return }
        purchasingProductId = "restore"
        defer { purchasingProductId = nil }
        do {
            let status = try await subscriptionService.restorePurchases(
                userId: session.userId,
                accessToken: session.accessToken
            )
            session.applyEntitlement(status.entitlement)
            statusMessage = session.l("paywall.restore_success")
            if status.entitlement?.isPremium == true {
                dismiss()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
