import SwiftUI

struct HiAirAtmosphericBackground: View {
    var date: Date = Date()
    var atmosphereTint: Color = HiAirColors.Spectrum.cyan

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift: CGFloat = 0

    var body: some View {
        ZStack {
            HiAirGradients.atmosphericBase()
            TimeOfDayBackground.gradient(for: date).opacity(0.45)

            RadialGradient(
                colors: [
                    atmosphereTint.opacity(0.55),
                    HiAirColors.Spectrum.cyan.opacity(0.26),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.18 + drift * 0.04, y: 0.12),
                startRadius: 8,
                endRadius: 340
            )

            RadialGradient(
                colors: [
                    HiAirColors.Spectrum.violet.opacity(0.48),
                    HiAirColors.Spectrum.magenta.opacity(0.24),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.88 - drift * 0.03, y: 0.82),
                startRadius: 12,
                endRadius: 380
            )

            LinearGradient(
                colors: [Color.white.opacity(0.035), Color.clear, Color.black.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: HiAirMotion.backgroundDrift).repeatForever(autoreverses: true)) {
                drift = 1
            }
        }
    }
}
