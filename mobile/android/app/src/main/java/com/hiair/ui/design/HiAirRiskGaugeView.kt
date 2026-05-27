package com.hiair.ui.design

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.SweepGradient
import android.util.AttributeSet
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.theme.V2Ui

class HiAirRiskGaugeView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : FrameLayout(context, attrs) {

    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        color = (HiAirColors.Text.primary and 0x00FFFFFF) or (HiAirColors.Overlay.borderSoftAlpha shl 24)
    }
    private val arcBounds = RectF()
    private var score: Int = 58
    private var riskLevel: String = "moderate"
    private var ringStrokePx: Float = V2Ui.dp(context, 10).toFloat()

    private val scoreView = TextView(context).apply {
        textSize = 48f
        setTypeface(typeface, android.graphics.Typeface.BOLD)
        setTextColor(HiAirColors.Text.primary)
        gravity = Gravity.CENTER
    }
    private val statusRow = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER
    }
    private val statusDot = android.view.View(context)
    private val statusLabel = TextView(context).apply {
        textSize = 15f
        setTextColor(HiAirColors.Text.primary)
    }
    private val centerColumn = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER
    }

    init {
        setWillNotDraw(false)
        statusRow.addView(statusDot)
        statusRow.addView(statusLabel)
        centerColumn.addView(scoreView)
        centerColumn.addView(statusRow)
        addView(
            centerColumn,
            LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.CENTER),
        )
        val dotParams = LinearLayout.LayoutParams(V2Ui.dp(context, 8), V2Ui.dp(context, 8)).apply {
            rightMargin = V2Ui.dp(context, 6)
            gravity = Gravity.CENTER_VERTICAL
        }
        statusDot.layoutParams = dotParams
    }

    fun bind(score: Int, statusLabelText: String, riskLevel: String) {
        this.score = score.coerceIn(0, 100)
        this.riskLevel = riskLevel
        scoreView.text = this.score.toString()
        statusLabel.text = statusLabelText
        val accent = HiAirRiskStyle.colorForLevel(riskLevel)
        statusDot.background = V2Ui.cardBackground(
            context,
            HiAirComponents.colorHex(accent),
            HiAirComponents.colorHex(accent),
            HiAirRadius.pill,
        )
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val min = V2Ui.dp(context, 200)
        val size = resolveSize(min, widthMeasureSpec).coerceAtMost(resolveSize(min, heightMeasureSpec))
        setMeasuredDimension(size, size)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val inset = ringStrokePx / 2f + V2Ui.dp(context, 4)
        arcBounds.set(inset, inset, width - inset, height - inset)
        trackPaint.strokeWidth = ringStrokePx
        ringPaint.strokeWidth = ringStrokePx

        canvas.drawArc(arcBounds, 0f, 360f, false, trackPaint)

        val accent = HiAirRiskStyle.colorForLevel(riskLevel)
        val shader = SweepGradient(
            width / 2f,
            height / 2f,
            intArrayOf(
                HiAirColors.Brand.orbViolet,
                HiAirColors.Cta.gradientEnd,
                HiAirColors.Cta.gradientStart,
                accent,
            ),
            null,
        )
        ringPaint.shader = shader
        val sweep = 360f * (score / 100f)
        canvas.drawArc(arcBounds, -90f, sweep, false, ringPaint)
        ringPaint.shader = null
    }
}
