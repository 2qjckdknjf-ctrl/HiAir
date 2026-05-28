import SwiftUI

struct HiAirLaunchView: View {
    var body: some View {
        ZStack {
            HiAirGradients.launchBackground()
                .ignoresSafeArea()
            VStack(spacing: HiAirSpacing.lg) {
                Image("HiAirLaunchLogo")
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .accessibilityLabel("HiAir")
                Image("HiAirWordmark")
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 48)
                    .accessibilityLabel("HiAir")
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
