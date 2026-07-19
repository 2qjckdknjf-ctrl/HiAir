package com.hiair.ui.render

import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import com.hiair.network.ApiClient
import com.hiair.network.ApiHttpException
import com.hiair.network.AppConfig
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.HiAirHumanDate
import com.hiair.ui.design.HiAirSpacing
import com.hiair.ui.design.Tokens
import com.hiair.ui.theme.V2Ui
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

internal object InsightsScreenRenderer {
    private val apiClient = ApiClient(AppConfig.apiBaseUrl)
    private const val TARGET_DAYS = 10

    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val bodyContainer = ctx.bodyContainer

        ctx.titleView.text = ctx.l("nav.insights")
        bodyContainer.addView(HiAirComponents.brandHeader(activity))

        val contentHost = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }
        bodyContainer.addView(contentHost)
        contentHost.addView(HiAirComponents.loadingState(activity, ctx.l("insights.loading")))

        fun paint(
            loggedDays: Int,
            insights: List<String>,
            sampleLines: List<String>,
            generatedAt: String,
            error: String?,
        ) {
            contentHost.removeAllViews()
            if (error != null) {
                contentHost.addView(
                    HiAirComponents.errorState(
                        activity,
                        title = ctx.l("common.error.title"),
                        message = error,
                        retryTitle = ctx.l("insights.retry"),
                        onRetry = { load(ctx, contentHost, ::paint) },
                    ),
                )
                return
            }

            contentHost.addView(buildProgressCard(ctx, loggedDays, generatedAt, insights.isNotEmpty()))
            contentHost.addView(buildChecklistCard(ctx))

            if (insights.isEmpty()) {
                contentHost.addView(
                    HiAirComponents.emptyState(
                        activity,
                        title = ctx.l("state.empty.insights.title"),
                        message = ctx.l("state.empty.insights.body"),
                        actionTitle = ctx.l("insights.next.log_symptoms"),
                        onAction = {
                            rootShell.openSymptoms()
                            ctx.rerender()
                        },
                    ),
                )
            } else {
                insights.forEachIndexed { index, text ->
                    val card = HiAirComponents.cardContainer(activity)
                    card.addView(V2Ui.styledBodyText(activity, text))
                    sampleLines.getOrNull(index)?.let { sample ->
                        card.addView(
                            V2Ui.styledSecondaryText(activity, sample).apply { textSize = 12f },
                        )
                    }
                    contentHost.addView(card)
                }
            }
        }

        load(ctx, contentHost, ::paint)

        bodyContainer.addView(
            HiAirComponents.primaryButton(activity, ctx.l("insights.refresh")).apply {
                setOnClickListener { load(ctx, contentHost, ::paint) }
            },
        )
    }

    private fun load(
        ctx: RenderContext,
        contentHost: LinearLayout,
        paint: (Int, List<String>, List<String>, String, String?) -> Unit,
    ) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        contentHost.removeAllViews()
        contentHost.addView(HiAirComponents.loadingState(activity, ctx.l("insights.loading")))
        Thread {
            val settings = rootShell.settingsViewModel.state
            val profileId = rootShell.settingsViewModel.ensureProfile()
                ?: rootShell.symptomLogViewModel.state.profileId.ifBlank { "" }
            if (profileId.isBlank()) {
                activity.runOnUiThread {
                    paint(0, emptyList(), emptyList(), "—", ctx.l("planner.profile_required"))
                }
                return@Thread
            }
            try {
                val insights = mutableListOf<String>()
                val samples = mutableListOf<String>()
                var generatedAt = "—"
                var loggedDays = 0

                try {
                    val bundleRaw = apiClient.fetchHealthInsights(
                        userId = settings.userId,
                        accessToken = settings.accessToken.ifBlank { null },
                        profileId = profileId,
                        language = settings.preferredLanguage,
                    )
                    val bundle = JSONObject(bundleRaw)
                    generatedAt = HiAirHumanDate.display(
                        bundle.optString("generatedAt"),
                        Locale.getDefault(),
                        HiAirHumanDate.Style.DATE_TIME,
                    )
                    fun appendCards(key: String) {
                        val arr = bundle.optJSONArray(key) ?: return
                        for (i in 0 until arr.length()) {
                            val row = arr.getJSONObject(i)
                            val title = row.optString("title")
                            val observation = row.optString("observation")
                            val recommendation = row.optString("recommendation")
                            val confidence = row.optString("confidence")
                            val text = buildString {
                                append(title)
                                if (observation.isNotBlank()) append("\n").append(observation)
                                if (recommendation.isNotBlank()) append("\n").append(recommendation)
                            }
                            insights.add(text)
                            samples.add(
                                ctx.l("insights.sample_size")
                                    .replace("%d", row.optInt("sampleSize", 0).toString()) +
                                    if (confidence.isNotBlank()) " · $confidence" else "",
                            )
                        }
                    }
                    appendCards("trends")
                    appendCards("associations")
                    val insufficient = bundle.optJSONArray("insufficientData")
                    if (insufficient != null) {
                        for (i in 0 until insufficient.length()) {
                            val row = insufficient.getJSONObject(i)
                            insights.add(row.optString("message"))
                            samples.add("${row.optInt("have", 0)}/${row.optInt("need", 0)}")
                            loggedDays = maxOf(loggedDays, row.optInt("have", 0))
                        }
                    }
                } catch (error: ApiHttpException) {
                    if (error.statusCode == 402) {
                        activity.runOnUiThread {
                            rootShell.settingsViewModel.requestShowPaywall()
                            ctx.rerender()
                        }
                        return@Thread
                    }
                    // Non-premium path falls through to legacy personal patterns when available.
                } catch (_: Exception) {
                    // Fall through to premium personal patterns.
                }

                if (insights.isEmpty()) {
                    try {
                        val patternsRaw = apiClient.fetchPersonalPatterns(
                            userId = settings.userId,
                            accessToken = settings.accessToken.ifBlank { null },
                            profileId = profileId,
                            language = settings.preferredLanguage,
                        )
                        val patterns = JSONObject(patternsRaw)
                        val items = patterns.optJSONArray("items")
                        if (items != null) {
                            for (i in 0 until items.length()) {
                                val row = items.getJSONObject(i)
                                insights.add(row.optString("humanReadableText"))
                                samples.add(
                                    ctx.l("insights.sample_size")
                                        .replace("%d", row.optInt("sampleSize", 0).toString()),
                                )
                            }
                        }
                        generatedAt = HiAirHumanDate.display(
                            patterns.optString("generatedAt"),
                            Locale.getDefault(),
                            HiAirHumanDate.Style.DATE_TIME,
                        )
                    } catch (error: ApiHttpException) {
                        if (error.statusCode == 402) {
                            activity.runOnUiThread {
                                rootShell.settingsViewModel.requestShowPaywall()
                                ctx.rerender()
                            }
                            return@Thread
                        }
                        throw error
                    }
                }

                if (loggedDays == 0) {
                    loggedDays = try {
                        val historyRaw = apiClient.fetchSymptomHistory(
                            userId = settings.userId,
                            accessToken = settings.accessToken.ifBlank { null },
                            profileId = profileId,
                        )
                        uniqueLogDays(JSONObject(historyRaw).optJSONArray("items"))
                    } catch (_: Exception) {
                        0
                    }
                }
                activity.runOnUiThread {
                    paint(loggedDays, insights, samples, generatedAt, null)
                }
            } catch (_: Exception) {
                activity.runOnUiThread {
                    paint(0, emptyList(), emptyList(), "—", ctx.l("insights.failed"))
                }
            }
        }.start()
    }

    private fun buildProgressCard(
        ctx: RenderContext,
        loggedDays: Int,
        generatedAt: String,
        hasInsights: Boolean,
    ): LinearLayout {
        val activity = ctx.activity
        val card = HiAirComponents.cardContainer(activity)
        card.addView(HiAirComponents.sectionHeader(activity, ctx.l("insights.progress_title")))
        val row = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val progress = ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = TARGET_DAYS
            progress = loggedDays.coerceIn(0, TARGET_DAYS)
            layoutParams = LinearLayout.LayoutParams(0, V2Ui.dp(activity, 12), 1f)
        }
        row.addView(progress)
        row.addView(
            TextView(activity).apply {
                text = "$loggedDays/$TARGET_DAYS"
                textSize = 16f
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(Tokens.Text.primary)
                setPadding(V2Ui.dp(activity, HiAirSpacing.sm), 0, 0, 0)
                contentDescription = ctx.l("insights.progress_days")
                    .replaceFirst("%d", loggedDays.toString())
                    .replaceFirst("%d", TARGET_DAYS.toString())
            },
        )
        card.addView(row)
        card.addView(
            V2Ui.styledSecondaryText(
                activity,
                ctx.l("insights.progress_days")
                    .replaceFirst("%d", loggedDays.toString())
                    .replaceFirst("%d", TARGET_DAYS.toString()),
            ),
        )
        if (generatedAt != "—") {
            card.addView(V2Ui.styledSecondaryText(activity, generatedAt).apply { textSize = 12f })
        }
        if (!hasInsights) {
            card.addView(V2Ui.styledSecondaryText(activity, ctx.l("state.empty.insights.body")))
        }
        return card
    }

    private fun buildChecklistCard(ctx: RenderContext): LinearLayout {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val card = HiAirComponents.cardContainer(activity)
        card.addView(HiAirComponents.sectionHeader(activity, ctx.l("insights.next_step")))
        card.addView(
            HiAirComponents.secondaryButton(activity, ctx.l("insights.next.log_symptoms")).apply {
                setOnClickListener {
                    rootShell.openSymptoms()
                    ctx.rerender()
                }
            },
        )
        card.addView(
            HiAirComponents.secondaryButton(activity, ctx.l("insights.next.open_planner")).apply {
                setOnClickListener {
                    rootShell.openPlanner()
                    ctx.rerender()
                }
            },
        )
        return card
    }

    private fun uniqueLogDays(items: org.json.JSONArray?): Int {
        if (items == null) return 0
        val days = mutableSetOf<String>()
        val calendar = Calendar.getInstance(TimeZone.getDefault())
        for (i in 0 until items.length()) {
            val iso = items.getJSONObject(i).optString("loggedAt")
            val instant = HiAirHumanDate.parseIso(iso) ?: continue
            calendar.timeInMillis = instant.toEpochMilli()
            days.add(
                "${calendar.get(Calendar.YEAR)}-${calendar.get(Calendar.MONTH)}-${calendar.get(Calendar.DAY_OF_MONTH)}",
            )
        }
        return days.size
    }
}
