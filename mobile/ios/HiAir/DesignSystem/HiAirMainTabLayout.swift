import SwiftUI

private struct FloatingTabBarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension EnvironmentValues {
    var hiAirFloatingTabBarHeight: CGFloat {
        get { self[FloatingTabBarHeightEnvironmentKey.self] }
        set { self[FloatingTabBarHeightEnvironmentKey.self] = newValue }
    }
}

private struct FloatingTabBarHeightEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = HiAirScreenMetrics.floatingTabBarFallbackHeight
}

extension HiAirScreenMetrics {
    static let floatingTabBarFallbackHeight: CGFloat = 88

    /// Soft fade above the floating tab bar so scroll content does not read through glass.
    static let mainTabContentFadeHeight: CGFloat = 18

    /// Extra breathing room above tab bar for the last scroll item (used with `safeAreaInset`).
    static let mainTabScrollTailSpacing: CGFloat = 44
}

/// Shared bottom chrome: material fade + floating tab bar (one layout for all main tabs).
private struct HiAirMainTabBarBottomChrome: View {
    @Binding var selection: Int
    let items: [HiAirFloatingTabItem]

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0),
                    .init(color: HiAirColors.Spectrum.cyan.opacity(0.05), location: 0.55),
                    .init(color: HiAirColors.Surface.bg1.opacity(0.22), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: HiAirScreenMetrics.mainTabContentFadeHeight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            HiAirFloatingTabBar(selection: $selection, items: items)
                .accessibilityIdentifier(HiAirAccessibilityID.Tabs.bar)
        }
    }
}

extension View {
    /// Tail spacing after `safeAreaInset` tab bar; prefer this over manual bottom padding.
    func hiAirMainTabScrollContent() -> some View {
        padding(.bottom, HiAirScreenMetrics.mainTabScrollTailSpacing)
    }

    func hiAirFloatingTabBarHeightReader() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: FloatingTabBarHeightKey.self, value: proxy.size.height)
            }
        }
    }
}

struct HiAirFloatingTabBarHost<Content: View>: View {
    @Binding var selection: Int
    let items: [HiAirFloatingTabItem]
    @ViewBuilder let content: () -> Content
    @State private var measuredTabBarHeight: CGFloat = HiAirScreenMetrics.floatingTabBarFallbackHeight

    var body: some View {
        content()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HiAirMainTabBarBottomChrome(selection: $selection, items: items)
                    .hiAirFloatingTabBarHeightReader()
            }
            .environment(\.hiAirFloatingTabBarHeight, measuredTabBarHeight)
            .onPreferenceChange(FloatingTabBarHeightKey.self) { height in
                if height > 1 {
                    measuredTabBarHeight = height
                }
            }
    }
}

extension View {
    func hiAirNativeFormChrome() -> some View {
        foregroundStyle(HiAirColors.Text.primary)
            .tint(HiAirColors.Cta.gradientStart)
            .colorScheme(.dark)
    }
}
