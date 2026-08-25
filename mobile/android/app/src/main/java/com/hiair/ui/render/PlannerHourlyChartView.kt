package com.hiair.ui.render

import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import android.util.AttributeSet
import android.view.View
import com.hiair.ui.design.Tokens
import kotlin.math.max

/** V4 hourly air-quality area chart for planner store screenshots. */
class PlannerHourlyChartView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {
    private var risks: List<String> = emptyList()

    private val axisPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Tokens.Surface.tileStroke
        strokeWidth = dp(1f)
        style = Paint.Style.STROKE
    }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    private val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Tokens.Feedback.info
        style = Paint.Style.STROKE
        strokeWidth = dp(2.25f)
        strokeJoin = Paint.Join.ROUND
        strokeCap = Paint.Cap.ROUND
    }
    private val peakPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Tokens.RiskAccent.high
        style = Paint.Style.FILL
    }
    private val peakRingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Tokens.Feedback.info
        style = Paint.Style.STROKE
        strokeWidth = dp(1.5f)
    }

    fun bindHourlyRisks(values: List<String>) {
        risks = values
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val local = risks.ifEmpty { List(24) { "moderate" } }
        val left = dp(8f)
        val right = width - dp(8f)
        val top = dp(8f)
        val bottom = height - dp(18f)
        val chartW = max(1f, right - left)
        val chartH = max(1f, bottom - top)
        val step = chartW / max(1, local.size - 1)
        val heights = local.map { riskHeight(it) * chartH }
        val path = Path()
        path.moveTo(left, bottom)
        local.indices.forEach { idx ->
            val x = left + idx * step
            val y = bottom - heights[idx]
            path.lineTo(x, y)
        }
        path.lineTo(left + (local.size - 1) * step, bottom)
        path.close()
        fillPaint.shader = LinearGradient(
            0f, top, 0f, bottom,
            intArrayOf(0x8821D7FF.toInt(), 0x3321D7FF, 0x0821D7FF),
            floatArrayOf(0f, 0.45f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawPath(path, fillPaint)
        fillPaint.shader = null
        val line = Path()
        local.indices.forEach { idx ->
            val x = left + idx * step
            val y = bottom - heights[idx]
            if (idx == 0) line.moveTo(x, y) else line.lineTo(x, y)
        }
        canvas.drawPath(line, linePaint)
        val peakIndex = heights.indices.maxByOrNull { heights[it] } ?: return
        val peakX = left + peakIndex * step
        val peakY = bottom - heights[peakIndex]
        canvas.drawCircle(peakX, peakY, dp(4f), peakPaint)
        canvas.drawCircle(peakX, peakY, dp(6f), peakRingPaint)
        canvas.drawLine(left, bottom, right, bottom, axisPaint)
    }

    private fun riskHeight(risk: String): Float = when (risk.lowercase()) {
        "low" -> 0.22f
        "moderate", "medium" -> 0.48f
        "high" -> 0.74f
        "very_high", "very high" -> 0.9f
        else -> 0.4f
    }

    private fun dp(value: Float): Float = value * resources.displayMetrics.density
}
