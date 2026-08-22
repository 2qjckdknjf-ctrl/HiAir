package com.hiair.ui.work

import com.hiair.ui.i18n.AndroidL10n
import org.json.JSONObject

data class WorkSiteRiskSnapshot(
    val riskLevel: String,
    val workMinutes: Int,
    val restMinutes: Int,
    val proxyOnly: Boolean,
    val summaryLine: String,
)

object WorkSiteRiskParser {
    fun parse(raw: String, preferredLanguage: String): WorkSiteRiskSnapshot {
        val json = JSONObject(raw)
        val assessment = json.getJSONObject("assessment")
        val workRest = assessment.getJSONObject("workRest")
        val reasonCodes = assessment.optJSONArray("reasonCodes")
        val proxyOnly = reasonCodes?.let { array ->
            (0 until array.length()).any { array.optString(it) == "heat_index_proxy_only" }
        } ?: false
        val riskLevel = assessment.optString("riskLevel", "unknown")
        val workMinutes = workRest.optInt("workMinutes", 0)
        val restMinutes = workRest.optInt("restMinutes", 0)
        val workRestLine = String.format(
            AndroidL10n.t("settings.work.work_rest", preferredLanguage),
            workMinutes,
            restMinutes,
        )
        val summaryLine = String.format(
            AndroidL10n.t("settings.work.summary", preferredLanguage),
            riskLevel,
            workRestLine,
        )
        return WorkSiteRiskSnapshot(
            riskLevel = riskLevel,
            workMinutes = workMinutes,
            restMinutes = restMinutes,
            proxyOnly = proxyOnly,
            summaryLine = summaryLine,
        )
    }
}
