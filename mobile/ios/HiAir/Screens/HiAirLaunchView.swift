import SwiftUI

struct HiAirLaunchView: View {
    var body: some View {
        ZStack {
            HiAirGradients.launchBackground()
                .ignoresSafeArea()
            VStack(spacing: HiAirSpacing.lg) {
                HiAirOrbLogoView(size: 120, animated: true, presentation: .brand)
                Text("HiAir")
                    .font(HiAirTypography.displayLG)
                    .foregroundStyle(HiAirColors.Text.primary)
                Text("Breathe better. Live better.")
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirColors.Cta.gradientStart)
            }
            .padding(HiAirSpacing.xl)
            .frame(maxWidth: HiAirScreenMetrics.contentMaxWidth)
        }
    }
}

#Preview {
    HiAirLaunchView()
}
