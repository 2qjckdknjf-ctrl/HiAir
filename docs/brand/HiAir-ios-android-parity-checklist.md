# HiAir iOS / Android Parity Checklist

Branch: `feat/hiair-brand-kit-system-redesign`  
Last updated: 2026-05-27

| Item | iOS | Android | Match |
|------|-----|---------|-------|
| App icon (orb on night bg) | Mockup AppIcon-1024 | Adaptive icon + foreground PNG | Yes |
| Splash / launch | LaunchScreen + HiAirOrb + cyan tagline | Theme.HiAir + hiair_orb splash | Yes |
| Brand header | HiAirBrandHeader (full + compact) | brandHeader (full + compact) | Yes |
| Dashboard hero orb ring | HiAirRiskGaugeView | HiAirRiskGaugeView | Yes |
| Dashboard compact logo | brandHeader compact | brandHeader compact | Yes |
| Dashboard weather orb | HiAirOrbLogoView brand PNG | brandOrbView PNG | Yes |
| HiAir Orb asset | Mockup PNG imageset | drawable/hiair_orb.png | Yes (final extract) |
| Background gradients | HiAirGradients / TimeOfDayPhase | TimeOfDayBackground | Yes (same hex) |
| Text colors | HiAirColors.Text | HiAirColors.Text / Tokens.Text | Yes |
| CTA gradient | HiAirGradientButtonStyle | HiAirComponents.primaryButton | Yes |
| Secondary buttons | HiAirSecondaryButtonStyle | HiAirComponents.secondaryButton | Yes |
| Risk chips | HiAirRiskChip | HiAirComponents.riskChip | Yes |
| Cards / radius | HiAirCard / HiAirGlassCard (20pt) | glassCardBackground (20dp) | Yes |
| Dashboard hero orb | HiAirRiskGaugeView + brand compact header | HiAirRiskGaugeView + brandOrbView | Yes |
| Auth layout | Orb + glass form + 1 CTA | Settings auth glass card + orb + 1 CTA | Yes (visual intent) |
| Onboarding | OnboardingView branded | OnboardingState only | Partial (platform gap pre-existing) |
| Empty/loading/error | HiAirEmptyStateView, HiAirLoadingView, HiAirErrorView | HiAirComponents empty/loading | Yes (API) |
| Typography hierarchy | HiAirTypography | V2Ui styled text | Equivalent |
| Pure red forbidden | Enforced in tokens | Enforced in tokens | Yes |

## Notes

- Android uses View-based renderers (not Compose); parity is visual/system-level, not pixel-identical.
- iOS has dedicated AuthView + OnboardingView; Android auth remains in Settings — **pre-existing product gap**, not introduced by this redesign.
- Final marketing-grade orb PNG/SVG superseded by mockup extract; optional design refresh later.
