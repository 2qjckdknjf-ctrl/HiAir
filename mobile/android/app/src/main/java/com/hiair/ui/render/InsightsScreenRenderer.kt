package com.hiair.ui.render

import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import com.hiair.ui.theme.V2Ui
import org.json.JSONObject

internal object InsightsScreenRenderer {
    private val apiClient = ApiClient(AppConfig.apiBaseUrl)

    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val titleView = ctx.titleView
        val bodyContainer = ctx.bodyContainer

        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("common.city_updated")).apply { textSize = 11f })
        titleView.text = ctx.l("nav.insights")
        val stateText = V2Ui.styledSecondaryText(activity, ctx.l("insights.loading"))
        val card = V2Ui.cardContainer(activity)
        card.addView(V2Ui.styledBodyText(activity, ctx.l("nav.insights")))
        card.addView(stateText)
        bodyContainer.addView(card)

        val refreshButton = V2Ui.primaryButton(activity, ctx.l("planner.refresh")).apply {
            setOnClickListener {
                val settings = rootShell.settingsViewModel.state
                val profileId = rootShell.symptomLogViewModel.state.profileId
                if (profileId.isBlank()) {
                    stateText.text = ctx.l("planner.profile_required")
                    return@setOnClickListener
                }
                stateText.text = ctx.l("insights.loading")
                Thread {
                    try {
                        val raw = apiClient.fetchPersonalPatterns(
                            userId = settings.userId,
                            accessToken = settings.accessToken.ifBlank { null },
                            profileId = profileId,
                            language = settings.preferredLanguage
                        )
                        val items = JSONObject(raw).optJSONArray("items")
                        val rendered = if (items == null || items.length() == 0) {
                            ctx.l("insights.unlock_more")
                        } else {
                            buildString {
                                for (idx in 0 until items.length()) {
                                    val row = items.getJSONObject(idx)
                                    append("• ${row.optString("humanReadableText")}\n")
                                }
                            }
                        }
                        activity.runOnUiThread { stateText.text = rendered.trim() }
                    } catch (_: Exception) {
                        activity.runOnUiThread { stateText.text = "${ctx.l("insights.failed")} ${ctx.l("insights.retry")}" }
                    }
                }.start()
            }
        }
        bodyContainer.addView(refreshButton)
    }
}
