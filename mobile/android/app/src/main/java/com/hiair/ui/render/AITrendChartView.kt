package com.hiair.ui.render

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.util.AttributeSet
import android.view.View
import kotlin.math.max

class AITrendChartView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : View(context, attrs) {
    private var points: List<Int> = emptyList()
    private var mode: String = "bars"

    private val axisPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#2E4B76")
        strokeWidth = dp(1f)
        style = Paint.Style.STROKE
    }
    private val barPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    private val latestBarStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#FFFFFF")
        style = Paint.Style.STROKE
        strokeWidth = dp(1.2f)
    }
    private val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#7BCBFF")
        style = Paint.Style.STROKE
        strokeWidth = dp(2f)
    }
    private val pointPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#7BCBFF")
        style = Paint.Style.FILL
    }
    private val latestPointPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#FFFFFF")
        style = Paint.Style.FILL
    }

    fun setTrendPoints(value: List<Int>) {
        points = value
        invalidate()
    }

    fun setChartMode(value: String) {
        mode = if (value == "line") "line" else "bars"
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val localPoints = points
        if (localPoints.isEmpty()) {
            canvas.drawRect(0f, height - dp(1f), width.toFloat(), height.toFloat(), axisPaint)
            return
        }

        val leftPad = dp(4f)
        val rightPad = dp(4f)
        val topPad = dp(4f)
        val bottomPad = dp(4f)
        val chartWidth = max(1f, width - leftPad - rightPad)
        val chartHeight = max(1f, height - topPad - bottomPad)
        val maxValue = max(1, localPoints.maxOrNull() ?: 1).toFloat()
        val barCount = localPoints.size
        val gap = dp(2f)
        val rawBarWidth = (chartWidth - gap * (barCount - 1)) / barCount
        val barWidth = max(dp(2f), rawBarWidth)

        if (mode == "line") {
            val step = if (barCount <= 1) 0f else (chartWidth / (barCount - 1))
            val path = Path()
            val pointsXY = ArrayList<Pair<Float, Float>>(barCount)
            for ((idx, value) in localPoints.withIndex()) {
                val ratio = (value / maxValue).coerceIn(0f, 1f)
                val x = leftPad + (idx * step)
                val y = topPad + (chartHeight - ratio * chartHeight)
                pointsXY.add(x to y)
                if (idx == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            canvas.drawPath(path, linePaint)
            for ((idx, pair) in pointsXY.withIndex()) {
                val (x, y) = pair
                val radius = if (idx == pointsXY.lastIndex) dp(3.5f) else dp(2.5f)
                val paint = if (idx == pointsXY.lastIndex) latestPointPaint else pointPaint
                canvas.drawCircle(x, y, radius, paint)
            }
        } else {
            var x = leftPad
            for ((idx, value) in localPoints.withIndex()) {
                val ratio = (value / maxValue).coerceIn(0f, 1f)
                val barHeight = ratio * chartHeight
                val yTop = topPad + (chartHeight - barHeight)
                barPaint.color = when {
                    ratio >= 0.75f -> Color.parseColor("#FF7B7B")
                    ratio >= 0.40f -> Color.parseColor("#FFD166")
                    else -> Color.parseColor("#4FC3F7")
                }
                canvas.drawRoundRect(
                    x,
                    yTop,
                    x + barWidth,
                    topPad + chartHeight,
                    dp(2f),
                    dp(2f),
                    barPaint
                )
                if (idx == barCount - 1) {
                    canvas.drawRoundRect(
                        x,
                        yTop,
                        x + barWidth,
                        topPad + chartHeight,
                        dp(2f),
                        dp(2f),
                        latestBarStrokePaint
                    )
                }
                x += barWidth + gap
            }
        }

        canvas.drawRect(leftPad, topPad + chartHeight, leftPad + chartWidth, topPad + chartHeight + dp(1f), axisPaint)
    }

    private fun dp(value: Float): Float = value * resources.displayMetrics.density
}
