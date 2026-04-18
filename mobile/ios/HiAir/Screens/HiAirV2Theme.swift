import SwiftUI

enum HiAirV2Theme {
    static let pageGradient = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.07, blue: 0.13),
            Color(red: 0.06, green: 0.11, blue: 0.19),
            Color(red: 0.03, green: 0.10, blue: 0.17)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardFill = Color(red: 0.08, green: 0.13, blue: 0.22).opacity(0.92)
    static let cardStroke = Color(red: 0.20, green: 0.30, blue: 0.45).opacity(0.35)
    static let primaryText = Color(red: 0.92, green: 0.95, blue: 0.99)
    static let secondaryText = Color(red: 0.64, green: 0.71, blue: 0.82)
    static let accentStart = Color(red: 0.36, green: 0.86, blue: 1.0)
    static let accentEnd = Color(red: 0.66, green: 0.60, blue: 1.0)
}

struct V2Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(HiAirV2Theme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(HiAirV2Theme.cardStroke, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func v2Card() -> some View {
        modifier(V2Card())
    }

    func v2PageBackground() -> some View {
        background(HiAirV2Theme.pageGradient.ignoresSafeArea())
    }
}

struct V2PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color(red: 0.05, green: 0.09, blue: 0.16))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                LinearGradient(
                    colors: [HiAirV2Theme.accentStart, HiAirV2Theme.accentEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: Color(red: 0.23, green: 0.61, blue: 1.0).opacity(0.24),
                radius: 14,
                x: 0,
                y: 6
            )
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
    }
}
