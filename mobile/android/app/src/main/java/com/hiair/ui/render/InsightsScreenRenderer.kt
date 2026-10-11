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
import com.hiair.ui.accessibility.HiAirGeometryMarkers
import com.hiair.ui.design.markGeometry
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
    @Volatile
    private var lastViewData: InsightsViewData? = null

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
        val ctx = ctx.withStoreContentRoot("insights")
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val bodyContainer = ctx.bodyContainer

