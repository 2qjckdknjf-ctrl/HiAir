package com.hiair.ui.render

import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.Tokens
import com.hiair.ui.theme.V2Ui
import java.util.Locale
import org.json.JSONObject

internal object HealthTodayMetricsRenderer {
    private val hiddenTypes = setOf(
        "blood_pressure_systolic",
        "blood_pressure_diastolic",
        "blood_glucose",
        "weight",
        "height",
        "body_fat",
    )

    private val displayOrder = listOf(
        "steps",
        "distance_walking_running",
        "active_energy",
        "exercise_minutes",
        "stand_minutes",
        "flights_climbed",
        "workout_count",
        "workout_duration",
        "heart_rate",
        "resting_heart_rate",
        "walking_heart_rate_avg",
        "hrv_sdnn",
        "hrv_rmssd",
        "respiratory_rate",
        "oxygen_saturation",
        "body_temperature",
        "wrist_temperature",
        "vo2_max",
        "mindfulness_minutes",
    )

    fun render(
        ctx: RenderContext,
        summaryRaw: String?,
        loadLevel: String?,
        loadExplanation: String?,
    ): View {
        val activity = ctx.activity
        val summary = summaryRaw?.let { runCatching { JSONObject(it) }.getOrNull() }
        val metricRows = metricRows(ctx, summary)
        val sleepRows = sleepRows(ctx, summary)

        return V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("health.today.title")).apply { textSize = 16f })
            addView(V2Ui.spacer(activity, 6))

            if (!loadLevel.isNullOrBlank()) {
                addView(
                    V2Ui.styledSecondaryText(
                        activity,
                        "${ctx.l("wearable.dashboard.load_risk")}: ${wearableLoadLabel(ctx, loadLevel)}",
                    ),
                )
                if (!loadExplanation.isNullOrBlank()) {
                    addView(V2Ui.styledSecondaryText(activity, loadExplanation).apply {
                        textSize = 12f
                        setTextColor(Tokens.Text.tertiary)
                    })
                }
            }

            if (metricRows.isEmpty() && sleepRows.isEmpty()) {
                addView(V2Ui.styledSecondaryText(activity, ctx.l("health.today.empty")))
            } else {
                metricRows.forEach { (label, value) ->
                    addView(metricTile(ctx, label, value))
                }
                if (sleepRows.isNotEmpty()) {
                    addView(
                        V2Ui.styledSecondaryText(activity, ctx.l("health.today.sleep_stages")).apply {
                            textSize = 12f
                            setTextColor(Tokens.Text.tertiary)
                            layoutParams = LinearLayout.LayoutParams(
                                LinearLayout.LayoutParams.MATCH_PARENT,
                                LinearLayout.LayoutParams.WRAP_CONTENT,
                            ).apply { topMargin = V2Ui.dp(activity, 8) }
                        },
                    )
                    sleepRows.forEach { (label, value) ->
                        addView(sleepRow(ctx, label, value))
                    }
                }
            }
        }
    }

    private fun metricRows(ctx: RenderContext, summary: JSONObject?): List<Pair<String, String>> {
        if (summary == null) return emptyList()
        val metrics = summary.optJSONArray("metrics") ?: return emptyList()
        val byType = mutableMapOf<String, JSONObject>()
        for (index in 0 until metrics.length()) {
            val metric = metrics.getJSONObject(index)
            byType[metric.optString("metricType")] = metric
        }

        val rows = mutableListOf<Pair<String, String>>()
        var seenHrv = false
        for (type in displayOrder) {
            if (type in hiddenTypes) continue
            if (type == "hrv_rmssd" && seenHrv) continue
            val metric = byType[type] ?: continue
            val raw = displayValue(metric) ?: continue
            if (type == "hrv_sdnn" || type == "hrv_rmssd") seenHrv = true
            val labelKey = if (type == "hrv_rmssd") "health.metric.hrv_sdnn" else "health.metric.$type"
            rows.add(ctx.l(labelKey) to formatMetric(ctx, type, raw, metric.optString("unit")))
        }
        return rows
    }

    private fun sleepRows(ctx: RenderContext, summary: JSONObject?): List<Pair<String, String>> {
        val sleep = summary?.optJSONObject("sleep") ?: return emptyList()
        val rows = mutableListOf<Pair<String, String>>()
        sleep.optInt("totalMinutes").takeIf { sleep.has("totalMinutes") && !sleep.isNull("totalMinutes") }?.let {
            rows.add(ctx.l("health.sleep.total") to "$it ${ctx.l("health.unit.min")}")
        }
        sleep.optInt("deepMinutes").takeIf { sleep.has("deepMinutes") && !sleep.isNull("deepMinutes") }?.let {
            rows.add(ctx.l("health.sleep.deep") to "$it ${ctx.l("health.unit.min")}")
        }
        sleep.optInt("remMinutes").takeIf { sleep.has("remMinutes") && !sleep.isNull("remMinutes") }?.let {
            rows.add(ctx.l("health.sleep.rem") to "$it ${ctx.l("health.unit.min")}")
        }
        sleep.optInt("coreLightMinutes").takeIf { sleep.has("coreLightMinutes") && !sleep.isNull("coreLightMinutes") }?.let {
            rows.add(ctx.l("health.sleep.core") to "$it ${ctx.l("health.unit.min")}")
        }
        sleep.optInt("awakeMinutes").takeIf { sleep.has("awakeMinutes") && !sleep.isNull("awakeMinutes") }?.let {
            rows.add(ctx.l("health.sleep.awake") to "$it ${ctx.l("health.unit.min")}")
        }
        sleep.optInt("inBedMinutes").takeIf { sleep.has("inBedMinutes") && !sleep.isNull("inBedMinutes") }?.let {
            rows.add(ctx.l("health.sleep.in_bed") to "$it ${ctx.l("health.unit.min")}")
        }
        return rows
    }

    private fun displayValue(metric: JSONObject): Double? {
        for (key in listOf("valueTotal", "valueAvg", "valueLatest")) {
            if (metric.has(key) && !metric.isNull(key)) {
                return metric.optDouble(key)
            }
        }
        return null
    }

    private fun formatMetric(ctx: RenderContext, metricType: String, value: Double, unit: String): String {
        return when (metricType) {
            "distance_walking_running" -> {
                val km = value / 1000.0
                String.format(Locale.US, "%.1f %s", km, ctx.l("health.unit.km"))
            }
            "oxygen_saturation" -> String.format(Locale.US, "%.0f%%", value)
            "body_temperature", "wrist_temperature" ->
                String.format(Locale.US, "%.1f %s", value, ctx.l("health.unit.celsius"))
            "vo2_max" -> String.format(Locale.US, "%.1f", value)
            else -> {
                if (unit == "count" || unit == "min" || unit == "kcal" || unit == "bpm" || unit == "ms") {
                    "${value.toInt()} ${localizedUnit(ctx, unit)}".trim()
                } else {
                    String.format(Locale.US, "%.0f %s", value, localizedUnit(ctx, unit))
                }
            }
        }
    }

    private fun localizedUnit(ctx: RenderContext, unit: String): String {
        return when (unit) {
            "min" -> ctx.l("health.unit.min")
            "kcal" -> ctx.l("health.unit.kcal")
            "bpm" -> ctx.l("health.unit.bpm")
            "ms" -> ctx.l("health.unit.ms")
            "count" -> ""
            else -> unit
        }
    }

    private fun metricTile(ctx: RenderContext, label: String, value: String): View {
        val activity = ctx.activity
        return LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(V2Ui.dp(activity, 10), V2Ui.dp(activity, 8), V2Ui.dp(activity, 10), V2Ui.dp(activity, 8))
            background = HiAirComponents.tileBackground(activity)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = V2Ui.dp(activity, 4) }
            addView(V2Ui.styledSecondaryText(activity, label).apply {
                textSize = 12f
                setTextColor(Tokens.Text.tertiary)
            })
            addView(V2Ui.styledBodyText(activity, value).apply {
                textSize = 14f
                contentDescription = "$label $value"
            })
        }
    }

    private fun sleepRow(ctx: RenderContext, label: String, value: String): View {
        val activity = ctx.activity
        return LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = V2Ui.dp(activity, 2) }
            addView(
                V2Ui.styledSecondaryText(activity, label).apply {
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                },
            )
            addView(V2Ui.styledBodyText(activity, value))
            contentDescription = "$label $value"
        }
    }

    private fun wearableLoadLabel(ctx: RenderContext, level: String): String {
        return when (level.lowercase(Locale.ROOT)) {
            "low" -> ctx.l("wearable.load.low")
            "moderate" -> ctx.l("wearable.load.moderate")
            "elevated", "high" -> ctx.l("wearable.load.elevated")
            else -> ctx.l("wearable.load.none")
        }
    }
}
