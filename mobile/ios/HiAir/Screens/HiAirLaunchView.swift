import SwiftUI

struct HiAirLaunchView: View {
    /// Launch runs before session injection; use preferred language from defaults.
    private var tagline: String {
        let lang = UserDefaults.standard.string(forKey: "preferredLanguage") ?? "en"
        return HiAirL10n.t("brand.tagline", lang: lang)
    }

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
                Text(tagline)
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
