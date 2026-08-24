import SwiftUI

enum HiAirDeepGlassCopy {
    static func t(_ key: String, lang: String) -> String {
        let table = table(for: lang)
        return table[key] ?? en[key] ?? key
    }

    private static func table(for lang: String) -> [String: String] {
        switch lang.lowercased().prefix(2) {
        case "ru": return ru
        case "es": return es
        case "it": return it
        case "fr": return fr
        default: return en
        }
    }

    private static let en: [String: String] = [
        "live": "Live",
        "greeting.morning": "Good morning",
        "greeting.afternoon": "Good afternoon",
        "greeting.evening": "Good evening",
        "tagline.smarter": "Breathe smarter.",
        "env_risk": "Environmental Risk",
        "spectrum.low": "Low",
        "spectrum.moderate": "Moderate",
        "spectrum.high": "High",
        "spectrum.very_high": "Very High",
        "weather": "Weather",
        "partly_cloudy": "Outdoor now",
        "aqi": "Air Quality Index",
        "good": "Good",
        "recommendations": "Recommendations",
        "view_all": "View all",
        "outdoor_window": "Outdoor window",
        "best_window": "Best air quality window %@",
        "best_window_prefix": "Best air quality window",
        "planner.title": "HiAir Planner",
        "today_risk": "Today's Risk",
        "best_outdoor": "Best Outdoor Window",
        "ventilation": "Ventilation Window",
        "chart_24h": "24-hour risk",
        "recommended": "Recommended window",
        "morning": "Morning",
        "day": "Day",
        "evening": "Evening",
        "night": "Night",
        "hydration": "Hydration",
        "hydrate_goal": "Stay hydrated throughout the day.",
        "health.title": "HiAir Health",
        "checkin": "Check-in",
        "how_feeling": "How are you feeling today?",
        "recovery": "Recovery",
        "guidance": "Guidance, not diagnosis",
        "intensity": "Intensity",
        "energy": "Energy",
        "onboarding.promise": "Breathe smarter. Live better.",
        "onboarding.sub": "HiAir delivers real-time insights to help you make healthier daily decisions.",
        "feat.air": "Air Quality",
        "feat.air.body": "Real-time AQI and pollutant levels around you.",
        "feat.heat": "Heat",
        "feat.heat.body": "Heat index and humidity to stay comfortable.",
        "feat.allergy": "Allergies",
        "feat.allergy.body": "Pollen and allergen forecasts to plan ahead.",
        "feat.outdoor": "Outdoor Exercise",
        "feat.outdoor.body": "Track conditions for safer, smarter workouts.",
        "why_location": "Why location matters",
        "why_location.body": "Your location helps HiAir provide accurate, real-time insights about the air around you.",
        "use_location": "Use my location",
        "manual_location": "Set location manually",
        "step_of": "%d of 6",
        "low_pollution": "Lower pollution window.",
        "ventilate_hint": "Good time to ventilate.",
        "heart": "Heart Rate",
        "steps": "Steps",
        "kcal": "Calories",
        "sleep": "Sleep",
        "today": "Today",
        "daily_metrics": "Daily Metrics",
        "symptom_checkin": "Symptom Check-in",
        "smart_insight": "Smart Insight",
        "aqi_us": "Risk",
        "humidity": "Humidity",
        "uv": "UV",
        "feels": "Feels like",
        "optimal_ventilate": "Optimal time to ventilate.",
        "low_pollution_uv": "Lower pollution window.",
        "hydrate_goal_l": "2.0 L goal",
        "mild": "Mild",
        "severe": "Severe",
        "outdoor_now": "Outdoor now",
    ]

    private static let ru: [String: String] = [
        "live": "Live",
        "greeting.morning": "Доброе утро",
        "greeting.afternoon": "Добрый день",
        "greeting.evening": "Добрый вечер",
        "tagline.smarter": "Дышите умнее.",
        "env_risk": "Экологический риск",
        "spectrum.low": "Низкий",
        "spectrum.moderate": "Умеренный",
        "spectrum.high": "Высокий",
        "spectrum.very_high": "Очень высокий",
        "weather": "Погода",
        "partly_cloudy": "Сейчас на улице",
        "aqi": "Индекс воздуха",
        "good": "Хорошо",
        "recommendations": "Рекомендации",
        "view_all": "Все",
        "outdoor_window": "Окно на улице",
        "best_window": "Лучшее окно качества воздуха %@",
        "best_window_prefix": "Лучшее окно качества воздуха",
        "planner.title": "HiAir План",
        "today_risk": "Риск сегодня",
        "best_outdoor": "Лучшее окно",
        "ventilation": "Проветривание",
        "chart_24h": "Риск за 24 часа",
        "recommended": "Рекомендуемое окно",
        "morning": "Утро",
        "day": "День",
        "evening": "Вечер",
        "night": "Ночь",
        "hydration": "Гидратация",
        "hydrate_goal": "Пейте воду в течение дня.",
        "health.title": "HiAir Health",
        "checkin": "Чек-ин",
        "how_feeling": "Как вы себя чувствуете сегодня?",
        "recovery": "Восстановление",
        "guidance": "Подсказка, не диагноз",
        "intensity": "Интенсивность",
        "energy": "Энергия",
        "onboarding.promise": "Дышите умнее. Живите лучше.",
        "onboarding.sub": "HiAir даёт подсказки в реальном времени, чтобы день был здоровее.",
        "feat.air": "Качество воздуха",
        "feat.air.body": "AQI и загрязнители рядом с вами.",
        "feat.heat": "Жара",
        "feat.heat.body": "Тепловой индекс и влажность.",
        "feat.allergy": "Аллергия",
        "feat.allergy.body": "Прогноз пыльцы и аллергенов.",
        "feat.outdoor": "Тренировки",
        "feat.outdoor.body": "Условия для более безопасных тренировок.",
        "why_location": "Зачем нужна геолокация",
        "why_location.body": "Локация нужна, чтобы HiAir точно оценивал воздух вокруг вас.",
        "use_location": "Использовать мою геолокацию",
        "manual_location": "Указать место вручную",
        "step_of": "%d из 6",
        "low_pollution": "Окно с меньшим загрязнением.",
        "ventilate_hint": "Хорошее время проветрить.",
        "heart": "Пульс",
        "steps": "Шаги",
        "kcal": "Ккал",
        "sleep": "Сон",
        "today": "Сегодня",
        "daily_metrics": "Метрики дня",
        "symptom_checkin": "Чек-ин симптомов",
        "smart_insight": "Подсказка",
        "aqi_us": "Риск",
        "humidity": "Влажность",
        "uv": "УФ",
        "feels": "Ощущается",
        "optimal_ventilate": "Лучшее время проветрить.",
        "low_pollution_uv": "Окно с меньшим загрязнением.",
        "hydrate_goal_l": "Цель 2,0 л",
        "mild": "Легко",
        "severe": "Сильно",
        "outdoor_now": "Сейчас на улице",
    ]

    private static let es: [String: String] = [
        "live": "Live",
        "greeting.morning": "Buenos días",
        "greeting.afternoon": "Buenas tardes",
        "greeting.evening": "Buenas noches",
        "tagline.smarter": "Respira mejor.",
        "env_risk": "Riesgo ambiental",
        "spectrum.low": "Bajo",
        "spectrum.moderate": "Moderado",
        "spectrum.high": "Alto",
        "spectrum.very_high": "Muy alto",
        "weather": "Tiempo",
        "partly_cloudy": "Ahora afuera",
        "aqi": "Índice de aire",
        "good": "Bueno",
        "recommendations": "Recomendaciones",
        "view_all": "Ver todo",
        "outdoor_window": "Ventana exterior",
        "best_window": "Mejor ventana de aire %@",
        "best_window_prefix": "Mejor ventana de aire",
        "planner.title": "HiAir Plan",
        "today_risk": "Riesgo de hoy",
        "best_outdoor": "Mejor ventana",
        "ventilation": "Ventilación",
        "chart_24h": "Riesgo 24 h",
        "recommended": "Ventana recomendada",
        "morning": "Mañana",
        "day": "Día",
        "evening": "Tarde",
        "night": "Noche",
        "hydration": "Hidratación",
        "hydrate_goal": "Mantente hidratado durante el día.",
        "health.title": "HiAir Health",
        "checkin": "Check-in",
        "how_feeling": "¿Cómo te sientes hoy?",
        "recovery": "Recuperación",
        "guidance": "Orientación, no diagnóstico",
        "intensity": "Intensidad",
        "energy": "Energía",
        "onboarding.promise": "Respira mejor. Vive mejor.",
        "onboarding.sub": "HiAir ofrece indicaciones en tiempo real para decisiones más sanas.",
        "feat.air": "Calidad del aire",
        "feat.air.body": "AQI y contaminantes a tu alrededor.",
        "feat.heat": "Calor",
        "feat.heat.body": "Índice de calor y humedad.",
        "feat.allergy": "Alergias",
        "feat.allergy.body": "Pronóstico de polen y alérgenos.",
        "feat.outdoor": "Ejercicio",
        "feat.outdoor.body": "Condiciones para entrenar con más seguridad.",
        "why_location": "Por qué importa la ubicación",
        "why_location.body": "La ubicación permite estimar el aire a tu alrededor.",
        "use_location": "Usar mi ubicación",
        "manual_location": "Definir ubicación manualmente",
        "step_of": "%d de 6",
        "low_pollution": "Ventana con menos contaminación.",
        "ventilate_hint": "Buen momento para ventilar.",
        "heart": "Pulso",
        "steps": "Pasos",
        "kcal": "Kcal",
        "sleep": "Sueño",
        "today": "Hoy",
        "daily_metrics": "Métricas del día",
        "symptom_checkin": "Registro de síntomas",
        "smart_insight": "Insight",
        "aqi_us": "Riesgo",
        "humidity": "Humedad",
        "uv": "UV",
        "feels": "Sensación",
        "optimal_ventilate": "Mejor momento para ventilar.",
        "low_pollution_uv": "Ventana con menos contaminación.",
        "hydrate_goal_l": "Meta 2,0 L",
        "mild": "Leve",
        "severe": "Severo",
        "outdoor_now": "Ahora afuera",
    ]

    private static let it: [String: String] = [
        "live": "Live",
        "greeting.morning": "Buongiorno",
        "greeting.afternoon": "Buon pomeriggio",
        "greeting.evening": "Buonasera",
        "tagline.smarter": "Respira meglio.",
        "env_risk": "Rischio ambientale",
        "spectrum.low": "Basso",
        "spectrum.moderate": "Moderato",
        "spectrum.high": "Alto",
        "spectrum.very_high": "Molto alto",
        "weather": "Meteo",
        "partly_cloudy": "Ora all'aperto",
        "aqi": "Indice dell'aria",
        "good": "Buono",
        "recommendations": "Raccomandazioni",
        "view_all": "Vedi tutto",
        "outdoor_window": "Finestra outdoor",
        "best_window": "Migliore finestra aria %@",
        "best_window_prefix": "Migliore finestra aria",
        "planner.title": "HiAir Piano",
        "today_risk": "Rischio di oggi",
        "best_outdoor": "Finestra migliore",
        "ventilation": "Ventilazione",
        "chart_24h": "Rischio 24 h",
        "recommended": "Finestra consigliata",
        "morning": "Mattina",
        "day": "Giorno",
        "evening": "Sera",
        "night": "Notte",
        "hydration": "Idratazione",
        "hydrate_goal": "Rimani idratato durante il giorno.",
        "health.title": "HiAir Health",
        "checkin": "Check-in",
        "how_feeling": "Come ti senti oggi?",
        "recovery": "Recupero",
        "guidance": "Indicazione, non diagnosi",
        "intensity": "Intensità",
        "energy": "Energia",
        "onboarding.promise": "Respira meglio. Vivi meglio.",
        "onboarding.sub": "HiAir offre insight in tempo reale per decisioni più sane.",
        "feat.air": "Qualità dell'aria",
        "feat.air.body": "AQI e inquinanti intorno a te.",
        "feat.heat": "Caldo",
        "feat.heat.body": "Indice di calore e umidità.",
        "feat.allergy": "Allergie",
        "feat.allergy.body": "Previsioni di polline e allergeni.",
        "feat.outdoor": "Allenamento",
        "feat.outdoor.body": "Condizioni per allenarti in sicurezza.",
        "why_location": "Perché serve la posizione",
        "why_location.body": "La posizione serve a stimare l'aria intorno a te.",
        "use_location": "Usa la mia posizione",
        "manual_location": "Imposta la posizione a mano",
        "step_of": "%d di 6",
        "low_pollution": "Finestra con meno inquinamento.",
        "ventilate_hint": "Buon momento per aerare.",
        "heart": "Battito",
        "steps": "Passi",
        "kcal": "Kcal",
        "sleep": "Sonno",
        "today": "Oggi",
        "daily_metrics": "Metriche del giorno",
        "symptom_checkin": "Check-in sintomi",
        "smart_insight": "Insight",
        "aqi_us": "Rischio",
        "humidity": "Umidità",
        "uv": "UV",
        "feels": "Percepita",
        "optimal_ventilate": "Momento migliore per aerare.",
        "low_pollution_uv": "Finestra con meno inquinamento.",
        "hydrate_goal_l": "Obiettivo 2,0 L",
        "mild": "Lieve",
        "severe": "Forte",
        "outdoor_now": "Ora all'aperto",
    ]

    private static let fr: [String: String] = [
        "live": "Live",
        "greeting.morning": "Bonjour",
        "greeting.afternoon": "Bon après-midi",
        "greeting.evening": "Bonsoir",
        "tagline.smarter": "Respirez mieux.",
        "env_risk": "Risque environnemental",
        "spectrum.low": "Faible",
        "spectrum.moderate": "Modéré",
        "spectrum.high": "Élevé",
        "spectrum.very_high": "Très élevé",
        "weather": "Météo",
        "partly_cloudy": "Dehors maintenant",
        "aqi": "Indice de l'air",
        "good": "Bon",
        "recommendations": "Recommandations",
        "view_all": "Tout voir",
        "outdoor_window": "Fenêtre extérieure",
        "best_window": "Meilleure fenêtre d'air %@",
        "best_window_prefix": "Meilleure fenêtre d'air",
        "planner.title": "HiAir Plan",
        "today_risk": "Risque du jour",
        "best_outdoor": "Meilleure fenêtre",
        "ventilation": "Ventilation",
        "chart_24h": "Risque 24 h",
        "recommended": "Fenêtre recommandée",
        "morning": "Matin",
        "day": "Jour",
        "evening": "Soir",
        "night": "Nuit",
        "hydration": "Hydratation",
        "hydrate_goal": "Restez hydraté toute la journée.",
        "health.title": "HiAir Health",
        "checkin": "Check-in",
        "how_feeling": "Comment vous sentez-vous aujourd'hui ?",
        "recovery": "Récupération",
        "guidance": "Conseil, pas un diagnostic",
        "intensity": "Intensité",
        "energy": "Énergie",
        "onboarding.promise": "Respirez mieux. Vivez mieux.",
        "onboarding.sub": "HiAir donne des insights en temps réel pour des décisions plus saines.",
        "feat.air": "Qualité de l'air",
        "feat.air.body": "AQI et polluants autour de vous.",
        "feat.heat": "Chaleur",
        "feat.heat.body": "Indice de chaleur et humidité.",
        "feat.allergy": "Allergies",
        "feat.allergy.body": "Prévisions pollen et allergènes.",
        "feat.outdoor": "Sport",
        "feat.outdoor.body": "Conditions pour s'entraîner plus sereinement.",
        "why_location": "Pourquoi la localisation",
        "why_location.body": "La localisation permet d'estimer l'air autour de vous.",
        "use_location": "Utiliser ma position",
        "manual_location": "Définir la position manuellement",
        "step_of": "%d sur 6",
        "low_pollution": "Fenêtre moins polluée.",
        "ventilate_hint": "Bon moment pour aérer.",
        "heart": "Pouls",
        "steps": "Pas",
        "kcal": "Kcal",
        "sleep": "Sommeil",
        "today": "Aujourd'hui",
        "daily_metrics": "Mesures du jour",
        "symptom_checkin": "Check-in symptômes",
        "smart_insight": "Insight",
        "aqi_us": "Risque",
        "humidity": "Humidité",
        "uv": "UV",
        "feels": "Ressenti",
        "optimal_ventilate": "Meilleur moment pour aérer.",
        "low_pollution_uv": "Fenêtre moins polluée.",
        "hydrate_goal_l": "Objectif 2,0 L",
        "mild": "Léger",
        "severe": "Fort",
        "outdoor_now": "Dehors maintenant",
    ]
}

struct HiAirDeepGlassOrb: View {
    var score: Int
    var levelLabel: String
    var riskLevel: String
    var diameter: CGFloat = 220
    var showsScore: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var spin: Double = 0

    private var accent: Color { HiAirRiskStyle.color(for: riskLevel) }

    private var levelAccent: Color {
        switch riskLevel.lowercased() {
        case "low":
            return HiAirColors.Spectrum.cyan
        case "high":
            return HiAirColors.Risk.high
        case "very_high", "very high":
            return HiAirColors.Spectrum.magenta
        default:
            return HiAirColors.Spectrum.violet
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            HiAirColors.Spectrum.cyan.opacity(0.55),
                            HiAirColors.Spectrum.violet.opacity(0.28),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: diameter * 0.16,
                        endRadius: diameter * 0.82
                    )
                )
                .frame(width: diameter * 1.32, height: diameter * 1.32)
                .blur(radius: 16)
                .scaleEffect(pulse ? 1.04 : 0.97)
                .opacity(0.98)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            HiAirColors.Spectrum.cyan,
                            HiAirColors.Spectrum.electricBlue,
                            HiAirColors.Spectrum.violet,
                            HiAirColors.Spectrum.magenta,
                            HiAirColors.Spectrum.cyan,
                        ],
                        center: .center
                    ),
                    lineWidth: diameter * 0.068
                )
                .frame(width: diameter * 0.96, height: diameter * 0.96)
                .rotationEffect(.degrees(spin))
                .shadow(color: accent.opacity(0.85), radius: 14)

            Circle()
                .stroke(HiAirColors.Spectrum.cyan.opacity(0.88), lineWidth: 2.4)
                .frame(width: diameter * 0.82, height: diameter * 0.82)

            Circle()
                .stroke(HiAirColors.Spectrum.magenta.opacity(0.45), lineWidth: 1.2)
                .frame(width: diameter * 0.76, height: diameter * 0.76)

            if showsScore {
                Circle()
                    .fill(Color(hex: 0x01060C))
                    .frame(width: diameter * 0.74, height: diameter * 0.74)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1.4)
                    )

                VStack(spacing: 3) {
                    Text("\(score)")
                        .font(.system(size: diameter * 0.32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .shadow(color: Color.black.opacity(0.9), radius: 1, y: 1)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(levelLabel)
                        .font(.system(size: max(14, diameter * 0.082), weight: .bold))
                        .foregroundStyle(levelAccent)
                }
            } else {
                Image("HiAirOrb")
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: diameter * 0.72, height: diameter * 0.72)
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            if reduceMotion {
                pulse = true
                return
            }
            withAnimation(.easeInOut(duration: HiAirMotion.orbBreath).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                spin = 360
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(levelLabel) \(score)")
    }
}

struct HiAirRiskSpectrumBar: View {
    var score: Int
    var lang: String

    private var progress: CGFloat {
        CGFloat(min(max(score, 0), 100)) / 100
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    HiAirColors.Risk.low,
                                    HiAirColors.Spectrum.cyan,
                                    HiAirColors.Risk.moderate,
                                    HiAirColors.Risk.high,
                                    HiAirColors.Risk.veryHigh,
                                    HiAirColors.Spectrum.magenta,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 8)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: HiAirColors.Spectrum.cyan.opacity(0.6), radius: 6)
                        .offset(x: max(0, geo.size.width * progress - 8))
                }
            }
            .frame(height: 16)
            HStack {
                label("0 " + HiAirDeepGlassCopy.t("spectrum.low", lang: lang))
                Spacer()
                label("25 " + HiAirDeepGlassCopy.t("spectrum.moderate", lang: lang))
                Spacer()
                label("50 " + HiAirDeepGlassCopy.t("spectrum.high", lang: lang))
                Spacer()
                label("75 " + HiAirDeepGlassCopy.t("spectrum.very_high", lang: lang))
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(HiAirColors.Text.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

struct HiAirGlassMetricTile: View {
    var title: String
    var value: String
    var subtitle: String
    var footnote: String
    var icon: String
    var accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(HiAirTypography.caption.weight(.semibold))
                    .foregroundStyle(HiAirColors.Text.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.55), radius: 6)
            }
            Text(value)
                .font(HiAirTypography.displayLG)
                .foregroundStyle(HiAirColors.Text.primary)
            Text(subtitle)
                .font(HiAirTypography.caption.weight(.semibold))
                .foregroundStyle(accent)
            Text(footnote)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(HiAirColors.Text.secondary)
                .lineLimit(2)
        }
        .padding(HiAirSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .hiAirGlassSurface(prominence: .standard, glow: accent)
    }
}

struct HiAirRecommendationRow: View {
    var icon: String
    var text: String
    var accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(accent.opacity(0.22))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                )
            Text(text)
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirColors.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HiAirColors.Text.secondary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

struct HiAirOutdoorWindowBar: View {
    var segments: [Color]
    var summary: String
    var highlightRange: String? = nil
    var todayLabel: String = "Today"

    private let times = ["6 AM", "9 AM", "12 PM", "3 PM", "6 PM", "9 PM"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !todayLabel.isEmpty {
                HStack {
                    Spacer()
                    Text(todayLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(HiAirColors.Spectrum.cyan)
                }
            }
            HStack(spacing: 3) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, color in
                    Capsule()
                        .fill(color)
                        .frame(height: 12)
                        .shadow(color: color.opacity(0.45), radius: 4)
                }
            }
            HStack {
                ForEach(times, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(HiAirColors.Text.secondary)
                    if label != times.last { Spacer() }
                }
            }
            (Text(summary) + (highlightRange.map { Text($0).foregroundColor(HiAirColors.Risk.low) } ?? Text("")))
                .font(HiAirTypography.bodyMD.weight(.semibold))
                .foregroundStyle(HiAirColors.Text.secondary)
        }
    }
}

struct HiAirDateStrip: View {
    var selected: Date
    var onSelect: (Date) -> Void

    var body: some View {
        let days = (-3...3).compactMap { offset -> Date? in
            Calendar.current.date(byAdding: .day, value: offset, to: Date())
        }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    let isOn = Calendar.current.isDate(day, inSameDayAs: selected)
                    let isToday = Calendar.current.isDateInToday(day)
                    Button {
                        guard isToday else { return }
                        HiAirHaptics.chipSelect()
                        onSelect(day)
                    } label: {
                        VStack(spacing: 4) {
                            Text(weekday(day))
                                .font(.system(size: 11, weight: .semibold))
                            Text(dayNumber(day))
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(isOn ? HiAirColors.Text.primary : HiAirColors.Text.secondary)
                        .opacity(isToday || isOn ? 1 : 0.92)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background {
                            if isOn {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(HiAirColors.Spectrum.cyan.opacity(0.18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(HiAirColors.Spectrum.cyan.opacity(0.7), lineWidth: 1)
                                    )
                                    .shadow(color: HiAirColors.Spectrum.cyan.opacity(0.35), radius: 8)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isToday)
                    .frame(minHeight: 44)
                }
            }
        }
    }

    private func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func dayNumber(_ date: Date) -> String {
        String(Calendar.current.component(.day, from: date))
    }
}

struct HiAirHourlyRiskChart: View {
    var points: [AirHourlyRiskPoint]
    var highlightStartHour: Int?
    var highlightEndHour: Int?

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(["100", "75", "50", "25", "0"], id: \.self) { tick in
                        Text(tick)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(HiAirColors.Text.secondary)
                        if tick != "0" { Spacer() }
                    }
                }
                .frame(height: 140)
                GeometryReader { geo in
                    let values = Array(points.prefix(24).map { Self.score(for: $0.overallRisk) })
                    let maxY: CGFloat = 100
                    ZStack(alignment: .leading) {
                        highlightBand(width: geo.size.width, height: geo.size.height)
                        areaPath(values: values, size: geo.size, maxY: maxY)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        HiAirColors.Spectrum.cyan.opacity(0.28),
                                        HiAirColors.Risk.moderate.opacity(0.18),
                                        HiAirColors.Risk.high.opacity(0.12),
                                        Color.clear,
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        currentTimeLine(width: geo.size.width, height: geo.size.height)
                        linePath(values: values, size: geo.size, maxY: maxY)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        HiAirColors.Spectrum.cyan,
                                        HiAirColors.Risk.moderate,
                                        HiAirColors.Risk.high,
                                        HiAirColors.Risk.veryHigh,
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                            )
                            .shadow(color: HiAirColors.Spectrum.cyan.opacity(0.45), radius: 8)
                    }
                }
                .frame(height: 140)
            }
            HStack {
                ForEach(["00", "04", "08", "12", "16", "20", "24"], id: \.self) { hour in
                    Text(hour)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(HiAirColors.Text.secondary)
                    if hour != "24" { Spacer() }
                }
            }
            .padding(.leading, 28)
        }
    }

    static func score(for risk: String) -> CGFloat {
        switch risk.lowercased() {
        case "low": return 20
        case "moderate", "medium": return 45
        case "high": return 70
        case "very_high", "very high": return 90
        default: return 20
        }
    }

    @ViewBuilder
    private func highlightBand(width: CGFloat, height: CGFloat) -> some View {
        if let start = highlightStartHour, let end = highlightEndHour, end > start {
            let x = width * CGFloat(start) / 24
            let w = width * CGFloat(end - start) / 24
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(HiAirColors.Spectrum.cyan.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(HiAirColors.Spectrum.cyan.opacity(0.55), lineWidth: 1)
                )
                .frame(width: w, height: height)
                .offset(x: x)
        }
    }

    @ViewBuilder
    private func currentTimeLine(width: CGFloat, height: CGFloat) -> some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())
        let x = width * (CGFloat(hour) + CGFloat(minute) / 60) / 24
        Path { path in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: height))
        }
        .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }

    private func areaPath(values: [CGFloat], size: CGSize, maxY: CGFloat) -> Path {
        Path { path in
            guard !values.isEmpty else { return }
            let step = size.width / CGFloat(max(values.count - 1, 1))
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * step
                let y = size.height - (value / maxY) * size.height
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
    }

    private func linePath(values: [CGFloat], size: CGSize, maxY: CGFloat) -> Path {
        Path { path in
            guard !values.isEmpty else { return }
            let step = size.width / CGFloat(max(values.count - 1, 1))
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * step
                let y = size.height - (value / maxY) * size.height
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}

struct HiAirDayPartCard: View {
    var title: String
    var hours: String
    var temperature: String
    var aqi: String
    var risk: String
    var bodyText: String
    var iconName: String = "sun.max.fill"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(HiAirRiskStyle.color(for: risk))
                Spacer()
            }
            Text(title)
                .font(HiAirTypography.caption.weight(.semibold))
                .foregroundStyle(HiAirColors.Text.secondary)
            Text(hours)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(HiAirColors.Text.secondary)
            if !temperature.isEmpty {
                Text(temperature)
                    .font(HiAirTypography.titleMD)
                    .foregroundStyle(HiAirColors.Text.primary)
            }
            HiAirStatusChip(riskLevel: risk, label: aqi)
            Text(bodyText)
                .font(.system(size: 10))
                .foregroundStyle(HiAirColors.Text.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .hiAirGlassSurface(prominence: .passive, glow: HiAirRiskStyle.color(for: risk))
    }
}

struct HiAirRecoveryHero: View {
    var percent: Int
    var title: String
    var bodyText: String
    var lang: String

    var body: some View {
        HStack(spacing: 14) {
            HiAirDeepGlassOrb(
                score: percent,
                levelLabel: HiAirDeepGlassCopy.t("good", lang: lang),
                riskLevel: percent >= 70 ? "low" : "moderate",
                diameter: 108
            )
            VStack(alignment: .leading, spacing: 8) {
                Text(HiAirDeepGlassCopy.t("recovery", lang: lang))
                    .font(HiAirTypography.caption.weight(.semibold))
                    .foregroundStyle(HiAirColors.Text.secondary)
                Text(title)
                    .font(HiAirTypography.titleLG)
                    .foregroundStyle(HiAirColors.Spectrum.cyan)
                Text(bodyText)
                    .font(HiAirTypography.caption)
                    .foregroundStyle(HiAirColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                GeometryReader { geo in
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(HiAirColors.Overlay.subtle)
                            .frame(height: 8)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(HiAirGradients.cta())
                                    .frame(
                                        width: max(8, (geo.size.width - 44) * CGFloat(min(max(percent, 0), 100)) / 100),
                                        height: 8
                                    )
                                    .shadow(color: HiAirColors.Spectrum.cyan.opacity(0.5), radius: 6)
                            }
                        Text("\(percent)%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HiAirColors.Text.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                .frame(height: 16)
            }
            Spacer(minLength: 0)
        }
        .padding(HiAirSpacing.md)
        .hiAirGlassSurface(prominence: .hero, glow: HiAirColors.Spectrum.cyan)
    }
}

struct HiAirSparkMetricCard: View {
    var title: String
    var value: String
    var accent: Color
    var icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(accent)
            Text(value)
                .font(HiAirTypography.bodyMD.weight(.semibold))
                .foregroundStyle(HiAirColors.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(HiAirColors.Text.secondary)
                .lineLimit(1)
            Capsule()
                .fill(accent.opacity(0.85))
                .frame(height: 3)
                .shadow(color: accent.opacity(0.45), radius: 4)
                .accessibilityHidden(true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .hiAirGlassSurface(prominence: .compact, glow: accent)
    }
}

struct HiAirOnboardingFeatureCard: View {
    var title: String
    var bodyText: String
    var icon: String
    var accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
            Text(title)
                .font(HiAirTypography.caption.weight(.semibold))
                .foregroundStyle(HiAirColors.Text.primary)
            Text(bodyText)
                .font(.system(size: 11))
                .foregroundStyle(HiAirColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .hiAirGlassSurface(prominence: .passive, glow: accent)
    }
}

struct HiAirProgressDots: View {
    var current: Int
    var total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? HiAirColors.Spectrum.cyan : HiAirColors.Text.tertiary.opacity(0.35))
                    .frame(width: index == current ? 18 : 7, height: 7)
            }
        }
    }
}
