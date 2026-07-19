"""Canonical comprehensive symptom taxonomy for HiAir wellness journaling.

Wellness language only — no diagnoses. Red-flag types show a safety notice.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class SymptomDefinition:
    symptom_type: str
    category: str
    labels: dict[str, str]
    red_flag: bool = False
    legacy_bool: str | None = None


CATEGORIES: dict[str, dict[str, str]] = {
    "respiratory": {"ru": "Дыхание", "en": "Breathing", "es": "Respiración", "it": "Respiro", "fr": "Respiration"},
    "allergy_nose_throat": {
        "ru": "Нос, горло, аллергия",
        "en": "Nose, throat, allergy",
        "es": "Nariz, garganta, alergia",
        "it": "Naso, gola, allergia",
        "fr": "Nez, gorge, allergie",
    },
    "eyes": {"ru": "Глаза", "en": "Eyes", "es": "Ojos", "it": "Occhi", "fr": "Yeux"},
    "heat_dehydration": {
        "ru": "Жара и обезвоживание",
        "en": "Heat and dehydration",
        "es": "Calor y deshidratación",
        "it": "Calore e disidratazione",
        "fr": "Chaleur et déshydratation",
    },
    "head_nervous": {
        "ru": "Голова и нервная система",
        "en": "Head and nervous system",
        "es": "Cabeza y sistema nervioso",
        "it": "Testa e sistema nervoso",
        "fr": "Tête et système nerveux",
    },
    "cardiovascular_sensation": {
        "ru": "Сердечно-сосудистые ощущения",
        "en": "Cardiovascular sensations",
        "es": "Sensaciones cardiovasculares",
        "it": "Sensazioni cardiovascolari",
        "fr": "Sensations cardiovasculaires",
    },
    "general": {"ru": "Общие", "en": "General", "es": "Generales", "it": "Generali", "fr": "Généraux"},
    "sleep_recovery": {
        "ru": "Сон и восстановление",
        "en": "Sleep and recovery",
        "es": "Sueño y recuperación",
        "it": "Sonno e recupero",
        "fr": "Sommeil et récupération",
    },
    "skin": {"ru": "Кожа", "en": "Skin", "es": "Piel", "it": "Pelle", "fr": "Peau"},
    "digestion": {"ru": "Пищеварение", "en": "Digestion", "es": "Digestión", "it": "Digestione", "fr": "Digestion"},
    "custom": {"ru": "Свои", "en": "Custom", "es": "Personalizados", "it": "Personalizzati", "fr": "Personnalisés"},
}

SAFETY_NOTICE = {
    "ru": (
        "При сильной боли в груди, выраженной одышке, потере сознания "
        "или резком ухудшении обратитесь за неотложной помощью."
    ),
    "en": (
        "If you have severe chest pain, severe shortness of breath, loss of "
        "consciousness, or a sudden sharp decline, seek emergency help."
    ),
    "es": (
        "Si tiene dolor torácico intenso, falta de aire grave, pérdida de "
        "conocimiento o un deterioro brusco, busque ayuda de emergencia."
    ),
    "it": (
        "In caso di forte dolore al petto, grave mancanza di respiro, perdita "
        "di conoscenza o peggioramento improvviso, chiedi aiuto di emergenza."
    ),
    "fr": (
        "En cas de douleur thoracique intense, de dyspnée sévère, de perte de "
        "connaissance ou d'aggravation brutale, demandez une aide d'urgence."
    ),
}


def _s(symptom_type: str, category: str, ru: str, en: str, *, red_flag: bool = False, legacy: str | None = None) -> SymptomDefinition:
    return SymptomDefinition(
        symptom_type=symptom_type,
        category=category,
        labels={"ru": ru, "en": en, "es": en, "it": en, "fr": en},
        red_flag=red_flag,
        legacy_bool=legacy,
    )


SYMPTOMS: tuple[SymptomDefinition, ...] = (
    # A. Respiratory
    _s("cough", "respiratory", "Кашель", "Cough", legacy="cough"),
    _s("dry_cough", "respiratory", "Сухой кашель", "Dry cough"),
    _s("wet_cough", "respiratory", "Влажный кашель", "Productive cough"),
    _s("wheeze", "respiratory", "Свистящее дыхание", "Wheeze", legacy="wheeze"),
    _s("shortness_of_breath", "respiratory", "Одышка", "Shortness of breath", red_flag=True),
    _s("difficult_inhale", "respiratory", "Затруднённый вдох", "Difficult inhale"),
    _s("difficult_exhale", "respiratory", "Затруднённый выдох", "Difficult exhale"),
    _s("chest_tightness", "respiratory", "Стеснение в груди", "Chest tightness", red_flag=True),
    _s("rapid_breathing", "respiratory", "Учащённое дыхание", "Rapid breathing"),
    _s("airway_irritation", "respiratory", "Раздражение дыхательных путей", "Airway irritation"),
    _s("air_hunger", "respiratory", "Ощущение нехватки воздуха", "Air hunger", red_flag=True),
    # B. Nose / throat / allergy
    _s("nasal_congestion", "allergy_nose_throat", "Заложенность носа", "Nasal congestion"),
    _s("runny_nose", "allergy_nose_throat", "Насморк", "Runny nose"),
    _s("sneezing", "allergy_nose_throat", "Чихание", "Sneezing"),
    _s("itchy_nose", "allergy_nose_throat", "Зуд в носу", "Itchy nose"),
    _s("throat_tickle", "allergy_nose_throat", "Першение", "Throat tickle"),
    _s("sore_throat", "allergy_nose_throat", "Боль в горле", "Sore throat"),
    _s("dry_throat", "allergy_nose_throat", "Сухость в горле", "Dry throat"),
    _s("hoarseness", "allergy_nose_throat", "Осиплость", "Hoarseness"),
    _s("postnasal_drip", "allergy_nose_throat", "Постназальный затёк", "Postnasal drip"),
    # C. Eyes
    _s("dry_eyes", "eyes", "Сухость глаз", "Dry eyes"),
    _s("eye_irritation", "eyes", "Раздражение глаз", "Eye irritation"),
    _s("itchy_eyes", "eyes", "Зуд глаз", "Itchy eyes"),
    _s("watery_eyes", "eyes", "Слезотечение", "Watery eyes"),
    _s("red_eyes", "eyes", "Покраснение глаз", "Red eyes"),
    _s("light_sensitivity", "eyes", "Чувствительность к свету", "Light sensitivity"),
    # D. Heat / dehydration
    _s("intense_thirst", "heat_dehydration", "Сильная жажда", "Intense thirst"),
    _s("dry_mouth", "heat_dehydration", "Сухость во рту", "Dry mouth"),
    _s("heavy_sweating", "heat_dehydration", "Усиленное потоотделение", "Heavy sweating"),
    _s("no_sweat_in_heat", "heat_dehydration", "Отсутствие потоотделения при жаре", "No sweat in heat", red_flag=True),
    _s("overheating", "heat_dehydration", "Ощущение перегрева", "Overheating", red_flag=True),
    _s("heat_intolerance", "heat_dehydration", "Непереносимость жары", "Heat intolerance"),
    _s("muscle_cramps", "heat_dehydration", "Мышечные судороги", "Muscle cramps"),
    _s("heat_weakness", "heat_dehydration", "Слабость при жаре", "Heat weakness"),
    _s("heat_dizziness", "heat_dehydration", "Головокружение при жаре", "Heat dizziness", red_flag=True),
    _s("near_fainting", "heat_dehydration", "Предобморочное состояние", "Near fainting", red_flag=True),
    _s("heat_nausea", "heat_dehydration", "Тошнота при жаре", "Heat nausea"),
    # E. Head / nervous
    _s("headache", "head_nervous", "Головная боль", "Headache", legacy="headache"),
    _s("migraine_like_pain", "head_nervous", "Мигренеподобная боль", "Migraine-like pain"),
    _s("dizziness", "head_nervous", "Головокружение", "Dizziness"),
    _s("brain_fog", "head_nervous", "Затуманенность мышления", "Brain fog"),
    _s("concentration_difficulty", "head_nervous", "Сложности концентрации", "Concentration difficulty"),
    _s("drowsiness", "head_nervous", "Сонливость", "Drowsiness"),
    _s("irritability", "head_nervous", "Раздражительность", "Irritability"),
    _s("coordination_issues", "head_nervous", "Нарушение координации", "Coordination issues", red_flag=True),
    _s("anxiety_feeling", "head_nervous", "Ощущение тревоги", "Feeling of anxiety"),
    _s("confusion", "head_nervous", "Спутанность сознания", "Confusion", red_flag=True),
    # F. Cardiovascular sensations (subjective only)
    _s("palpitations_feeling", "cardiovascular_sensation", "Ощущение учащённого сердцебиения", "Feeling of palpitations"),
    _s("skipped_beat_feeling", "cardiovascular_sensation", "Ощущение перебоев", "Feeling of skipped beats"),
    _s("high_pulse_feeling", "cardiovascular_sensation", "Необычно высокий пульс по ощущениям", "Unusually high pulse feeling"),
    _s("exertion_weakness", "cardiovascular_sensation", "Слабость при нагрузке", "Weakness on exertion"),
    _s("orthostatic_dizziness", "cardiovascular_sensation", "Головокружение при вставании", "Dizziness on standing"),
    _s("chest_discomfort", "cardiovascular_sensation", "Дискомфорт в груди", "Chest discomfort", red_flag=True),
    # G. General
    _s("fatigue", "general", "Усталость", "Fatigue", legacy="fatigue"),
    _s("weakness", "general", "Слабость", "Weakness"),
    _s("low_energy", "general", "Снижение энергии", "Low energy"),
    _s("body_aches", "general", "Ломота", "Body aches"),
    _s("chills", "general", "Озноб", "Chills"),
    _s("malaise", "general", "Плохое самочувствие", "Malaise"),
    _s("reduced_performance", "general", "Снижение работоспособности", "Reduced performance"),
    _s("exercise_intolerance", "general", "Непереносимость нагрузки", "Exercise intolerance"),
    # H. Sleep / recovery
    _s("hard_to_fall_asleep", "sleep_recovery", "Трудно заснуть", "Hard to fall asleep"),
    _s("frequent_awakenings", "sleep_recovery", "Частые пробуждения", "Frequent awakenings"),
    _s("early_waking", "sleep_recovery", "Раннее пробуждение", "Early waking"),
    _s("unrefreshed_sleep", "sleep_recovery", "Невыспанность", "Unrefreshed sleep"),
    _s("poor_sleep_quality", "sleep_recovery", "Плохое качество сна", "Poor sleep quality"),
    _s("daytime_sleepiness", "sleep_recovery", "Дневная сонливость", "Daytime sleepiness"),
    _s("morning_unusual_fatigue", "sleep_recovery", "Необычная усталость утром", "Unusual morning fatigue"),
    # I. Skin
    _s("dry_skin", "skin", "Сухость кожи", "Dry skin"),
    _s("itchy_skin", "skin", "Зуд кожи", "Itchy skin"),
    _s("skin_redness", "skin", "Покраснение кожи", "Skin redness"),
    _s("rash", "skin", "Сыпь", "Rash"),
    _s("skin_irritation", "skin", "Раздражение кожи", "Skin irritation"),
    _s("sun_reaction", "skin", "Реакция на солнце", "Sun reaction"),
    # J. Digestion (no automatic air/heat linkage)
    _s("nausea", "digestion", "Тошнота", "Nausea"),
    _s("low_appetite", "digestion", "Снижение аппетита", "Low appetite"),
    _s("abdominal_discomfort", "digestion", "Дискомфорт в животе", "Abdominal discomfort"),
    _s("diarrhea", "digestion", "Диарея", "Diarrhea"),
    _s("vomiting", "digestion", "Рвота", "Vomiting"),
)

_BY_TYPE = {item.symptom_type: item for item in SYMPTOMS}
_LEGACY = {item.legacy_bool: item.symptom_type for item in SYMPTOMS if item.legacy_bool}


def all_symptom_types() -> set[str]:
    return set(_BY_TYPE)


def get_symptom(symptom_type: str) -> SymptomDefinition | None:
    return _BY_TYPE.get(symptom_type)


def is_known_symptom(symptom_type: str) -> bool:
    return symptom_type in _BY_TYPE or symptom_type.startswith("custom:")


def is_red_flag(symptom_type: str) -> bool:
    item = _BY_TYPE.get(symptom_type)
    return bool(item and item.red_flag)


def legacy_type_for_bool(field: str) -> str | None:
    return _LEGACY.get(field)


def taxonomy_payload(language: str = "ru") -> dict:
    lang = language if language in ("ru", "en", "es", "it", "fr") else "ru"
    categories = []
    for category_id, labels in CATEGORIES.items():
        if category_id == "custom":
            continue
        items = [
            {
                "symptomType": item.symptom_type,
                "label": item.labels.get(lang) or item.labels["en"],
                "redFlag": item.red_flag,
            }
            for item in SYMPTOMS
            if item.category == category_id
        ]
        categories.append(
            {
                "id": category_id,
                "label": labels.get(lang) or labels["en"],
                "symptoms": items,
            }
        )
    return {
        "consentVersion": "health-intelligence-v1",
        "severityNotice": SAFETY_NOTICE.get(lang, SAFETY_NOTICE["en"]),
        "severityNoticeAlwaysVisible": True,
        "severityNoticeContext": "red_flag_symptoms",
        "categories": categories,
        "severitySymptomTypes": [item.symptom_type for item in SYMPTOMS if item.red_flag],
        "count": len(SYMPTOMS),
    }
