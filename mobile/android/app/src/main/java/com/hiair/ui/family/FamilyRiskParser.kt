package com.hiair.ui.family

import com.hiair.ui.i18n.AndroidL10n
import org.json.JSONObject

data class FamilyMemberRiskItem(
    val memberLinkId: String,
    val memberProfileId: String,
    val relation: String,
    val label: String?,
    val riskLevel: String,
    val riskScore: Int,
    val available: Boolean,
    val unavailableReason: String?,
)

object FamilyRiskParser {
    fun parseOverview(raw: String): List<FamilyMemberRiskItem> {
        val members = JSONObject(raw).optJSONArray("members") ?: return emptyList()
        return buildList {
            for (index in 0 until members.length()) {
                val row = members.getJSONObject(index)
                add(
                    FamilyMemberRiskItem(
                        memberLinkId = row.optString("memberLinkId"),
                        memberProfileId = row.optString("memberProfileId"),
                        relation = row.optString("relation"),
                        label = row.optString("label").takeIf { it.isNotBlank() },
                        riskLevel = row.optString("riskLevel"),
                        riskScore = row.optInt("riskScore", 0),
                        available = row.optBoolean("available", false),
                        unavailableReason = row.optString("unavailableReason").takeIf { it.isNotBlank() },
                    ),
                )
            }
        }
    }

    fun riskLabel(item: FamilyMemberRiskItem?, preferredLanguage: String): String {
        if (item == null) return ""
        if (!item.available) {
            return AndroidL10n.t("settings.family.risk_unavailable", preferredLanguage)
        }
        val levelKey = when (item.riskLevel.lowercase()) {
            "low" -> "hazards.level.low"
            "moderate", "medium" -> "hazards.level.moderate"
            "high" -> "hazards.level.high"
            "very_high", "very high" -> "hazards.level.very_high"
            else -> null
        }
        val level = levelKey?.let { AndroidL10n.t(it, preferredLanguage) } ?: item.riskLevel
        return AndroidL10n.t("settings.family.risk_line", preferredLanguage)
            .replace("%s", level)
            .replace("%d", item.riskScore.toString())
    }
}
