import SwiftUI

struct HiAirFloatingTabItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let systemImage: String
    let selectedSystemImage: String
    let accessibilityID: String
}

struct HiAirFloatingTabBar: View {
    @Binding var selection: Int
    let items: [HiAirFloatingTabItem]
    @Namespace private var tabGlow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .hiAirGlassSurface(
            prominence: .active,
            cornerRadius: HiAirRadius.tabBar,
            glow: HiAirColors.Spectrum.cyan
        )
        .padding(.horizontal, HiAirSpacing.md)
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)
    }

    private func tabButton(_ item: HiAirFloatingTabItem) -> some View {
        let selected = selection == item.id
        return Button {
            guard selection != item.id else { return }
            HiAirHaptics.tabChange()
            withAnimation(reduceMotion ? .easeOut(duration: 0.12) : HiAirMotion.tabChange) {
                selection = item.id
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if selected {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(HiAirColors.Spectrum.cyan.opacity(0.28))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(HiAirColors.Spectrum.cyan, lineWidth: 1.6)
                            )
                            .shadow(color: HiAirColors.Spectrum.cyan.opacity(0.85), radius: 16, y: 2)
                            .matchedGeometryEffect(id: "selectedTab", in: tabGlow)
                    }
                    Image(systemName: selected ? item.selectedSystemImage : item.systemImage)
                        .font(.system(size: 18, weight: selected ? .bold : .regular))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(selected ? Color.white : HiAirColors.Text.secondary)
                        .shadow(color: selected ? HiAirColors.Spectrum.cyan.opacity(0.9) : .clear, radius: 8)
                }
                .frame(width: 52, height: 36)

                Text(item.title)
                    .font(.system(size: 10, weight: selected ? .bold : .semibold))
                    .foregroundStyle(selected ? HiAirColors.Spectrum.cyan : HiAirColors.Text.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(item.title)
        .accessibilityIdentifier(item.accessibilityID)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}
