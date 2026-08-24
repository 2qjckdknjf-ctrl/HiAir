package com.hiair.ui.render

import android.graphics.Typeface
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import com.hiair.StoreScreenshotMode
import com.hiair.network.ApiClient
import com.hiair.network.ApiHttpException
import com.hiair.network.AppConfig
import com.hiair.ui.design.HiAirResponsiveLayout
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.insights.InsightsProgressContract
import com.hiair.ui.design.HiAirHumanDate
import com.hiair.ui.design.HiAirSpacing
import com.hiair.ui.design.Tokens
import com.hiair.ui.insights.AdaptationInsightsParser
import com.hiair.ui.insights.AdaptationSnapshot
import com.hiair.ui.theme.V2Ui
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

internal object InsightsScreenRenderer {
    private val apiClient = ApiClient(AppConfig.apiBaseUrl)
    private const val TARGET_DAYS = 7
    @Volatile
    private var selectedWindowDays: Int = 30

    private data class InsightCardData(
        val title: String,
        val observation: String,
        val recommendation: String,
        val confidence: String,
        val sampleSize: Int,
    )

    private data class InsufficientCardData(
        val message: String,
        val have: Int,
        val need: Int,
    )

    private data class InsightsViewData(
        val trends: List<InsightCardData>,
        val associations: List<InsightCardData>,
        val insufficient: List<InsufficientCardData>,
        val premiumPatterns: List<Pair<String, Int>>,
        val todaySummary: String,
        val generatedAt: String,
        val loggedDays: Int,
        val healthStatusText: String? = null,
        val premiumLocked: Boolean = false,
        val adaptation: AdaptationSnapshot? = null,
        val adaptationPremiumLocked: Boolean = false,
    )

    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val bodyContainer = ctx.bodyContainer

        ctx.titleView.text = ctx.l("nav.insights")
        if (HiAirComponents.shouldShowCompactBrandHeader()) {
            bodyContainer.addView(HiAirComponents.brandHeader(activity))
        }

        val contentHost = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }
        bodyContainer.addView(contentHost)
        contentHost.addView(HiAirComponents.loadingState(activity, ctx.l("insights.loading")))

        fun paint(data: InsightsViewData?, error: String?) {
            contentHost.removeAllViews()
            val repaint: (InsightsViewData?, String?) -> Unit = { nextData, nextError ->
                paint(nextData, nextError)
            }
            if (error != null) {
                contentHost.addView(
                    HiAirComponents.errorState(
                        activity,
                        title = ctx.l("common.error.title"),
                        message = error,
                        retryTitle = ctx.l("insights.retry"),
                        onRetry = { load(ctx, contentHost, repaint) },
                    ),
                )
                return
            }
            val viewData = data ?: InsightsViewData(
                trends = emptyList(),
                associations = emptyList(),
                insufficient = emptyList(),
                premiumPatterns = emptyList(),
                todaySummary = ctx.l("insights.today.empty"),
                generatedAt = ctx.l("common.unavailable"),
                loggedDays = 0,
                premiumLocked = false,
            )
            if (viewData.premiumLocked) {
                contentHost.addView(buildPremiumLockedCard(ctx))
                return
            }
            val hasInsights = viewData.trends.isNotEmpty() ||
                viewData.associations.isNotEmpty() ||
                viewData.premiumPatterns.isNotEmpty()

            contentHost.addView(
                buildWindowPicker(ctx) {
                    load(ctx, contentHost, repaint)
                },
            )
            contentHost.addView(buildProgressCard(ctx, viewData.loggedDays, viewData.generatedAt, hasInsights))
            contentHost.addView(buildChecklistCard(ctx))
            contentHost.addView(buildTodayCard(ctx, viewData.todaySummary, viewData.generatedAt))
            contentHost.addView(buildTrendsSection(ctx, viewData.trends))
            contentHost.addView(buildAssociationsSection(ctx, viewData.associations))
            contentHost.addView(buildInsufficientSection(ctx, viewData.insufficient))
            if (viewData.healthStatusText != null) {
                contentHost.addView(buildHealthStatusCard(ctx, viewData.healthStatusText))
            }
            if (viewData.adaptationPremiumLocked) {
                contentHost.addView(buildAdaptationPremiumLockedCard(ctx))
            } else if (viewData.adaptation != null) {
                contentHost.addView(buildAdaptationSection(ctx, viewData.adaptation))
            }
            if (viewData.premiumPatterns.isNotEmpty()) {
                contentHost.addView(buildPremiumPatternsSection(ctx, viewData.premiumPatterns))
            }

            if (!hasInsights && viewData.insufficient.isEmpty()) {
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
            }
        }

        val initialPaint: (InsightsViewData?, String?) -> Unit = { data, error -> paint(data, error) }
        if (StoreScreenshotMode.active) {
            paint(storeScreenshotDemoData(ctx), null)
            return
        }
        load(ctx, contentHost, initialPaint)

        bodyContainer.addView(
            HiAirComponents.primaryButton(activity, ctx.l("insights.refresh")).apply {
                setOnClickListener { load(ctx, contentHost, initialPaint) }
            },
        )
    }

    private fun load(
        ctx: RenderContext,
        contentHost: LinearLayout,
        paint: (InsightsViewData?, String?) -> Unit,
    ) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val unavailable = ctx.l("common.unavailable")
        contentHost.removeAllViews()
        contentHost.addView(HiAirComponents.loadingState(activity, ctx.l("insights.loading")))
        Thread {
            val settings = rootShell.settingsViewModel.state
            val profileId = rootShell.settingsViewModel.ensureProfile()
                ?: rootShell.symptomLogViewModel.state.profileId.ifBlank { "" }
            if (profileId.isBlank()) {
                activity.runOnUiThread {
                    paint(null, ctx.l("planner.profile_required"))
                }
                return@Thread
            }
            try {
                val trends = mutableListOf<InsightCardData>()
                val associations = mutableListOf<InsightCardData>()
                val insufficient = mutableListOf<InsufficientCardData>()
                val premiumPatterns = mutableListOf<Pair<String, Int>>()
                var generatedAt = unavailable
                var todaySummary = ctx.l("insights.today.empty")
                var loggedDays = 0
                var premiumLocked = false
                var healthStatusText: String? = null
                var adaptation: AdaptationSnapshot? = null
                var adaptationPremiumLocked = false

                try {
                    val bundleRaw = apiClient.fetchHealthInsights(
                        userId = settings.userId,
                        accessToken = settings.accessToken.ifBlank { null },
                        profileId = profileId,
                        language = settings.preferredLanguage,
                        windowDays = selectedWindowDays,
                    )
                    val bundle = JSONObject(bundleRaw)
                    generatedAt = HiAirHumanDate.display(
                        bundle.optString("generatedAt"),
                        Locale.getDefault(),
                        HiAirHumanDate.Style.DATE_TIME,
                        unavailable = unavailable,
                    )
                    todaySummary = formatToday(ctx, bundle.optJSONObject("today"))
                    healthStatusText = formatHealthStatus(ctx, bundle.optJSONObject("healthDataStatus"))
                    fun parseCards(key: String, target: MutableList<InsightCardData>) {
                        val arr = bundle.optJSONArray(key) ?: return
                        for (i in 0 until arr.length()) {
                            val row = arr.getJSONObject(i)
                            target.add(
                                InsightCardData(
                                    title = row.optString("title"),
                                    observation = row.optString("observation"),
                                    recommendation = row.optString("recommendation"),
                                    confidence = row.optString("confidence"),
                                    sampleSize = row.optInt("sampleSize", 0),
                                ),
                            )
                        }
                    }
                    parseCards("trends", trends)
                    parseCards("associations", associations)
                    val insufficientArr = bundle.optJSONArray("insufficientData")
                    if (insufficientArr != null) {
                        for (i in 0 until insufficientArr.length()) {
                            val row = insufficientArr.getJSONObject(i)
                            val have = row.optInt("have", 0)
                            insufficient.add(
                                InsufficientCardData(
                                    message = row.optString("message"),
                                    have = have,
                                    need = row.optInt("need", 0),
                                ),
                            )
                            loggedDays = maxOf(loggedDays, have)
                        }
                    }
                } catch (error: ApiHttpException) {
                    if (error.statusCode == 402) {
                        premiumLocked = true
                    }
                } catch (_: Exception) {
                    // Fall through to premium personal patterns.
                }

                try {
                    val adaptationRaw = apiClient.fetchAdaptation(
                        userId = settings.userId,
                        accessToken = settings.accessToken.ifBlank { null },
                        profileId = profileId,
                    )
                    adaptation = AdaptationInsightsParser.parse(adaptationRaw)
                } catch (error: ApiHttpException) {
                    if (error.statusCode == 402) {
                        adaptationPremiumLocked = true
                    }
                } catch (_: Exception) {
                    // Adaptation is optional enrichment.
                }

                if (!premiumLocked && trends.isEmpty() && associations.isEmpty() && insufficient.isEmpty()) {
                    try {
                        val patternsRaw = apiClient.fetchPersonalPatterns(
                            userId = settings.userId,
                            accessToken = settings.accessToken.ifBlank { null },
                            profileId = profileId,
                            windowDays = selectedWindowDays,
                            language = settings.preferredLanguage,
                        )
                        val patterns = JSONObject(patternsRaw)
                        val items = patterns.optJSONArray("items")
                        if (items != null) {
                            for (i in 0 until items.length()) {
                                val row = items.getJSONObject(i)
                                premiumPatterns.add(
                                    row.optString("humanReadableText") to row.optInt("sampleSize", 0),
                                )
                            }
                        }
                        generatedAt = HiAirHumanDate.display(
                            patterns.optString("generatedAt"),
                            Locale.getDefault(),
                            HiAirHumanDate.Style.DATE_TIME,
                            unavailable = unavailable,
                        )
                    } catch (error: ApiHttpException) {
                        if (error.statusCode == 402) {
                            premiumLocked = true
                        } else {
                            throw error
                        }
                    }
                }

                if (premiumLocked) {
                    activity.runOnUiThread {
                        paint(
                            InsightsViewData(
                                trends = emptyList(),
                                associations = emptyList(),
                                insufficient = emptyList(),
                                premiumPatterns = emptyList(),
                                todaySummary = todaySummary,
                                generatedAt = generatedAt,
                                loggedDays = loggedDays,
                                premiumLocked = true,
                            ),
                            null,
                        )
                    }
                    return@Thread
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
                    paint(
                        InsightsViewData(
                            trends = trends,
                            associations = associations,
                            insufficient = insufficient,
                            premiumPatterns = premiumPatterns,
                            todaySummary = todaySummary,
                            generatedAt = generatedAt,
                            loggedDays = loggedDays,
                            healthStatusText = healthStatusText,
                            adaptation = adaptation,
                            adaptationPremiumLocked = adaptationPremiumLocked,
                        ),
                        null,
                    )
                }
            } catch (_: Exception) {
                activity.runOnUiThread {
                    paint(null, ctx.l("insights.failed"))
                }
            }
        }.start()
    }

    private fun formatToday(ctx: RenderContext, today: JSONObject?): String {
        if (today == null) return ctx.l("insights.today.empty")
        val parts = mutableListOf<String>()
        if (today.has("steps")) {
            parts.add(ctx.l("insights.today.steps").replace("%d", today.optInt("steps", 0).toString()))
        }
        if (today.has("sleepMinutes")) {
            parts.add(ctx.l("insights.today.sleep").replace("%d", today.optInt("sleepMinutes", 0).toString()))
        }
        if (today.has("restingHeartRate")) {
            parts.add(ctx.l("insights.today.rhr").replace("%d", today.optInt("restingHeartRate", 0).toString()))
        }
        if (today.has("hrv")) {
            parts.add(ctx.l("insights.today.hrv").replace("%d", today.optInt("hrv", 0).toString()))
        }
        val spo2 = when {
            today.has("oxygenSaturation") -> today.optInt("oxygenSaturation", 0)
            today.has("spo2") -> today.optInt("spo2", 0)
            else -> null
        }
        if (spo2 != null) {
            parts.add(ctx.l("insights.today.spo2").replace("%d", spo2.toString()))
        }
        if (today.has("respiratoryRate")) {
            parts.add(ctx.l("insights.today.resp").replace("%d", today.optInt("respiratoryRate", 0).toString()))
        }
        if (today.has("distanceMeters")) {
            val km = today.optInt("distanceMeters", 0) / 1000.0
            parts.add(String.format(Locale.US, ctx.l("insights.today.distance"), km))
        }
        if (today.has("activeEnergyKcal")) {
            parts.add(ctx.l("insights.today.energy").replace("%d", today.optInt("activeEnergyKcal", 0).toString()))
        }
        if (today.has("vo2Max")) {
            parts.add(ctx.l("insights.today.vo2").replace("%d", today.optInt("vo2Max", 0).toString()))
        }
        if (today.has("workoutCount") && today.optInt("workoutCount", 0) > 0) {
            parts.add(ctx.l("insights.today.workouts").replace("%d", today.optInt("workoutCount", 0).toString()))
        }
        return parts.joinToString(" · ").ifBlank { ctx.l("insights.today.empty") }
    }

    private fun formatHealthStatus(ctx: RenderContext, status: JSONObject?): String? {
        if (status == null) {
            return null
        }
        val syncKey = when (status.optString("syncStatus").lowercase(Locale.ROOT)) {
            "ok", "success", "synced" -> "insights.sync.ok"
            "partial" -> "insights.sync.partial"
            "pending", "syncing" -> "insights.sync.pending"
            "error", "failed" -> "insights.sync.error"
            else -> "insights.sync.unknown"
        }
        val metrics = status.optInt("metricDays", 0)
        val syncLabel = ctx.l(syncKey)
        return ctx.l("insights.health_status")
            .replaceFirst("%d", metrics.toString())
            .replaceFirst("%@", syncLabel)
    }

    private fun buildHealthStatusCard(ctx: RenderContext, healthStatusText: String): LinearLayout {
        val activity = ctx.activity
        val section = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        section.addView(HiAirComponents.sectionHeader(activity, ctx.l("insights.section.health_status")))
        val card = HiAirComponents.cardContainer(activity)
        card.addView(V2Ui.styledSecondaryText(activity, healthStatusText))
        section.addView(card)
        return section
    }

    private fun buildAdaptationPremiumLockedCard(ctx: RenderContext): LinearLayout {
        return buildPremiumLockedCard(ctx)
    }

    private fun buildAdaptationSection(ctx: RenderContext, snapshot: AdaptationSnapshot): LinearLayout {
        val activity = ctx.activity
        val section = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        section.addView(HiAirComponents.sectionHeader(activity, ctx.l("adaptation.title")))
        val card = HiAirComponents.cardContainer(activity)
        val availableBaselines = snapshot.baselines.filter { it.available }
        if (availableBaselines.isEmpty()) {
            card.addView(V2Ui.styledSecondaryText(activity, ctx.l("adaptation.baselines.empty")))
        } else {
            card.addView(V2Ui.styledBodyText(activity, ctx.l("adaptation.baselines.title")).apply {
                setTypeface(typeface, Typeface.BOLD)
            })
            availableBaselines.forEach { baseline ->
                val valueText = baseline.value?.let { String.format(Locale.US, "%.1f", it) }
                    ?: ctx.l("common.unavailable")
                val line = ctx.l("adaptation.baseline.line")
                    .replaceFirst("%@", adaptationMetricLabel(ctx, baseline.metric))
                    .replaceFirst("%@", adaptationWindowLabel(ctx, baseline.window))
                    .replaceFirst("%@", valueText)
                    .replaceFirst("%d", baseline.sampleSize.toString())
                card.addView(V2Ui.styledSecondaryText(activity, line))
            }
        }
        card.addView(V2Ui.spacer(activity, 8))
        if (snapshot.protectedDays.available) {
            card.addView(V2Ui.styledBodyText(activity, ctx.l("adaptation.protected.title")).apply {
                setTypeface(typeface, Typeface.BOLD)
            })
            val protected = snapshot.protectedDays
            listOf(
                ctx.l("adaptation.protected.avoided") to protected.highRiskPeriodsAvoided,
                ctx.l("adaptation.protected.workouts") to protected.workoutsMoved,
                ctx.l("adaptation.protected.ventilation") to protected.ventilationWindowsUsed,
                ctx.l("adaptation.protected.exposure") to protected.poorAirExposureReduced,
            ).forEach { (label, count) ->
                card.addView(V2Ui.styledSecondaryText(activity, "$label: $count"))
            }
        } else {
            card.addView(V2Ui.styledSecondaryText(activity, ctx.l("adaptation.protected.empty")))
        }
        if (snapshot.generatedAt.isNotBlank()) {
            card.addView(
                V2Ui.styledSecondaryText(
                    activity,
                    HiAirHumanDate.display(
                        snapshot.generatedAt,
                        Locale.getDefault(),
                        HiAirHumanDate.Style.DATE_TIME,
                        unavailable = ctx.l("common.unavailable"),
                    ),
                ).apply { textSize = 12f },
            )
        }
        section.addView(card)
        return section
    }

    private fun adaptationMetricLabel(ctx: RenderContext, metric: String): String {
        val key = when (metric.lowercase(Locale.ROOT)) {
            "resting_heart_rate" -> "adaptation.metric.rhr"
            "hrv" -> "adaptation.metric.hrv"
            "sleep_minutes" -> "adaptation.metric.sleep"
            "steps" -> "adaptation.metric.steps"
            "exercise_minutes" -> "adaptation.metric.exercise"
            else -> null
        }
        return key?.let { ctx.l(it) } ?: metric
    }

    private fun adaptationWindowLabel(ctx: RenderContext, window: String): String {
        return when (window.lowercase(Locale.ROOT)) {
            "d7" -> ctx.l("adaptation.window.d7")
            "d30" -> ctx.l("adaptation.window.d30")
            else -> window
        }
    }

    private fun buildPremiumLockedCard(ctx: RenderContext): LinearLayout {
        val activity = ctx.activity
        return HiAirComponents.cardContainer(activity).apply {
            addView(HiAirComponents.sectionTitle(activity, ctx.l("insights.premium_locked.title")))
            addView(V2Ui.styledSecondaryText(activity, ctx.l("insights.premium_locked.body")))
            addView(V2Ui.spacer(activity, 8))
            addView(
                HiAirComponents.primaryButton(activity, ctx.l("insights.premium_locked.cta")).apply {
                    setOnClickListener {
                        ctx.rootShell.settingsViewModel.requestShowPaywall()
                        ctx.rerender()
                    }
                },
            )
        }
    }

    private fun confidenceLabel(ctx: RenderContext, value: String): String {
        return when (value.lowercase(Locale.ROOT)) {
            "preliminary" -> ctx.l("insights.confidence.preliminary")
            "moderate" -> ctx.l("insights.confidence.moderate")
            "stronger", "high" -> ctx.l("insights.confidence.high")
            "insufficient" -> ctx.l("insights.confidence.insufficient")
            else -> if (value.isBlank()) "" else value
        }
    }

    private fun buildInsightCard(ctx: RenderContext, card: InsightCardData): LinearLayout {
        val activity = ctx.activity
        val container = HiAirComponents.cardContainer(activity)
        if (card.title.isNotBlank()) {
            container.addView(
                V2Ui.styledBodyText(activity, card.title).apply {
                    textSize = 16f
                    setTypeface(typeface, Typeface.BOLD)
                },
            )
        }
        if (card.observation.isNotBlank()) {
            container.addView(V2Ui.styledSecondaryText(activity, card.observation))
        }
        if (card.recommendation.isNotBlank()) {
            container.addView(V2Ui.styledBodyText(activity, card.recommendation))
        }
        val meta = buildString {
            if (card.sampleSize > 0) {
                append(ctx.l("insights.sample_size").replace("%d", card.sampleSize.toString()))
            }
            val confidence = confidenceLabel(ctx, card.confidence)
            if (confidence.isNotBlank()) {
                if (isNotEmpty()) append(" · ")
                append(confidence)
            }
        }
        if (meta.isNotBlank()) {
            container.addView(V2Ui.styledSecondaryText(activity, meta).apply { textSize = 12f })
        }
        return container
    }

    private fun buildWindowPicker(
        ctx: RenderContext,
        onWindowChanged: () -> Unit,
    ): LinearLayout {
        val activity = ctx.activity
        val section = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        section.addView(HiAirComponents.sectionHeader(activity, ctx.l("insights.window.title")))
        val row = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.START
        }
        fun chip(days: Int, labelKey: String) {
            val selected = selectedWindowDays == days
            row.addView(
                HiAirComponents.secondaryButton(activity, ctx.l(labelKey)).apply {
                    alpha = if (selected) 1f else 0.72f
                    setOnClickListener {
                        if (selectedWindowDays == days) return@setOnClickListener
                        selectedWindowDays = days
                        onWindowChanged()
                    }
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    ).apply { marginEnd = HiAirSpacing.md }
                },
            )
        }
        chip(7, "insights.window.7d")
        chip(30, "insights.window.30d")
        section.addView(row)
        return section
    }

    private fun buildTodayCard(ctx: RenderContext, todaySummary: String, generatedAt: String): LinearLayout {
        val activity = ctx.activity
        val unavailable = ctx.l("common.unavailable")
        val section = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        section.addView(HiAirComponents.sectionHeader(activity, ctx.l("insights.section.today")))
        val card = HiAirComponents.cardContainer(activity)
        card.addView(V2Ui.styledSecondaryText(activity, todaySummary))
        if (generatedAt != unavailable) {
            card.addView(V2Ui.styledSecondaryText(activity, generatedAt).apply { textSize = 12f })
        }
        section.addView(card)
        return section
    }

    private fun buildTrendsSection(ctx: RenderContext, trends: List<InsightCardData>): LinearLayout {
        val activity = ctx.activity
        val section = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        section.addView(HiAirComponents.sectionHeader(activity, ctx.l("insights.section.trends")))
        if (trends.isEmpty()) {
            section.addView(V2Ui.styledSecondaryText(activity, ctx.l("insights.section.trends.empty")))
        } else {
            trends.forEach { section.addView(buildInsightCard(ctx, it)) }
        }
        return section
    }

    private fun buildAssociationsSection(ctx: RenderContext, associations: List<InsightCardData>): LinearLayout {
        val activity = ctx.activity
        val section = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        section.addView(HiAirComponents.sectionHeader(activity, ctx.l("insights.section.associations")))
        if (associations.isEmpty()) {
            section.addView(V2Ui.styledSecondaryText(activity, ctx.l("insights.section.associations.empty")))
        } else {
            associations.forEach { section.addView(buildInsightCard(ctx, it)) }
        }
        return section
    }

    private fun buildInsufficientSection(ctx: RenderContext, insufficient: List<InsufficientCardData>): LinearLayout {
        val activity = ctx.activity
        val section = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        if (insufficient.isEmpty()) return section
        section.addView(HiAirComponents.sectionHeader(activity, ctx.l("insights.section.insufficient")))
        insufficient.forEach { item ->
            val card = HiAirComponents.cardContainer(activity)
            card.addView(V2Ui.styledSecondaryText(activity, item.message))
            if (item.need > 0) {
                card.addView(
                    V2Ui.styledSecondaryText(activity, ctx.l("insights.progress_days")
                        .replaceFirst("%d", item.have.toString())
                        .replaceFirst("%d", item.need.toString()),
                    ).apply { textSize = 12f },
                )
            }
            section.addView(card)
        }
        return section
    }

    private fun buildPremiumPatternsSection(ctx: RenderContext, patterns: List<Pair<String, Int>>): LinearLayout {
        val activity = ctx.activity
        val section = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        section.addView(HiAirComponents.sectionHeader(activity, ctx.l("insights.section.premium_patterns")))
        patterns.forEach { (text, sampleSize) ->
            val card = HiAirComponents.cardContainer(activity)
            card.addView(V2Ui.styledBodyText(activity, text))
            if (sampleSize > 0) {
                card.addView(
                    V2Ui.styledSecondaryText(activity, ctx.l("insights.sample_size")
                        .replace("%d", sampleSize.toString())).apply { textSize = 12f },
                )
            }
            section.addView(card)
        }
        return section
    }

    private fun buildProgressCard(
        ctx: RenderContext,
        loggedDays: Int,
        generatedAt: String,
        hasInsights: Boolean,
    ): LinearLayout {
        val activity = ctx.activity
        val unavailable = ctx.l("common.unavailable")
        val denominator = InsightsProgressContract.denominatorForWindow(selectedWindowDays)
        val clampedDays = InsightsProgressContract.clampLoggedDays(loggedDays, denominator)
        val card = HiAirComponents.cardContainer(activity)
        card.addView(HiAirComponents.sectionHeader(activity, ctx.l("insights.progress_title")))
        val row = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val progress = ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = denominator
            progress = clampedDays
            layoutParams = LinearLayout.LayoutParams(0, V2Ui.dp(activity, 12), 1f)
        }
        row.addView(progress)
        row.addView(
            TextView(activity).apply {
                text = InsightsProgressContract.formatFraction(loggedDays, denominator)
                textSize = 16f
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(Tokens.Text.primary)
                setPadding(V2Ui.dp(activity, HiAirSpacing.sm), 0, 0, 0)
                contentDescription = ctx.l("insights.progress_days")
                    .replaceFirst("%d", clampedDays.toString())
                    .replaceFirst("%d", denominator.toString())
            },
        )
        card.addView(row)
        card.addView(
            V2Ui.styledSecondaryText(
                activity,
                ctx.l("insights.progress_days")
                    .replaceFirst("%d", clampedDays.toString())
                    .replaceFirst("%d", denominator.toString()),
            ),
        )
        if (generatedAt != unavailable) {
            card.addView(V2Ui.styledSecondaryText(activity, generatedAt).apply { textSize = 12f })
        }
        if (!hasInsights) {
            card.addView(V2Ui.styledSecondaryText(activity, ctx.l("state.empty.insights.body")))
        }
        card.layoutParams = HiAirResponsiveLayout.readingColumnLayoutParams(activity)
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

    private fun storeScreenshotDemoData(ctx: RenderContext): InsightsViewData {
        val ru = ctx.rootShell.settingsViewModel.state.preferredLanguage.startsWith("ru")
        return InsightsViewData(
            trends = listOf(
                InsightCardData(
                    title = if (ru) "Улучшение дыхания" else "Breathing improvement",
                    observation = if (ru) "AQI ниже среднего 3 дня" else "AQI below average for 3 days",
                    recommendation = if (ru) "Планируйте прогулки утром" else "Plan morning walks",
                    confidence = if (ru) "Высокая" else "High",
                    sampleSize = 12,
                ),
            ),
            associations = listOf(
                InsightCardData(
                    title = if (ru) "Утренние прогулки" else "Morning walks",
                    observation = if (ru) "Меньше симптомов до 10:00" else "Fewer symptoms before 10:00",
                    recommendation = if (ru) "Сохраняйте ритм" else "Keep the rhythm",
                    confidence = if (ru) "Средняя" else "Medium",
                    sampleSize = 8,
                ),
            ),
            insufficient = emptyList(),
            premiumPatterns = listOf("ventilation_window" to 4),
            todaySummary = if (ru) "Сегодня воздух благоприятный для прогулок." else "Air is favorable for outdoor time today.",
            generatedAt = if (ru) "Сегодня, 08:30" else "Today, 8:30 AM",
            loggedDays = 5,
            healthStatusText = if (ru) "Health Connect: демо" else "Health Connect: demo",
            premiumLocked = false,
        )
    }
}
