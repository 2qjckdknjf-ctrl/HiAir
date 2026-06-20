package com.hiair.share

import android.content.Context
import android.content.Intent
import com.hiair.StoredSession
import com.hiair.ui.i18n.AndroidL10n
import com.hiair.ui.navigation.RootShellViewModel

object ShareHelper {
    fun shareDashboard(context: Context, rootShell: RootShellViewModel, language: String) {
        val state = rootShell.dashboardViewModel.state
        val score = state.riskScore?.toString() ?: "—"
        val walk = state.safeWindows.firstOrNull() ?: AndroidL10n.t("dashboard.no_safe_window", language)
        val warning = state.morningBriefing.ifBlank { state.explanation }
        val footer = AndroidL10n.t("share.generated_by", language)

        val text = buildString {
            appendLine(AndroidL10n.t("share.title", language))
            appendLine("${AndroidL10n.t("share.risk", language)}: $score (${state.riskLevel})")
            appendLine("${AndroidL10n.t("share.best_walk", language)}: $walk")
            if (warning.isNotBlank()) {
                appendLine("${AndroidL10n.t("share.warning", language)}: $warning")
            }
            appendLine()
            append(footer)
        }

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        context.startActivity(Intent.createChooser(intent, AndroidL10n.t("dashboard.share", language)))
    }

    fun shareFromSession(context: Context, session: StoredSession) {
        val language = session.preferredLanguage
        val text = buildString {
            appendLine(AndroidL10n.t("share.title", language))
            appendLine("${AndroidL10n.t("share.location", language)}: ${session.homeLat}, ${session.homeLon}")
            appendLine(AndroidL10n.t("share.generated_by", language))
        }
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        context.startActivity(Intent.createChooser(intent, AndroidL10n.t("dashboard.share", language)))
    }
}
