package com.hiair.ui.design

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.util.AttributeSet
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.R
import com.hiair.ui.theme.V2Ui

class HiAirRiskGaugeView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : FrameLayout(context, attrs) {

    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val innerRingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = HiAirColors.Spectrum.cyan
        strokeWidth = V2Ui.dp(context, 2).toFloat()
    }
    private val diskPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.parseColor("#01060C")
    }
    private val diskStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = (HiAirColors.Text.primary and 0x00FFFFFF) or 0x38000000
        strokeWidth = V2Ui.dp(context, 1).toFloat()
    }
    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    private val arcBounds = RectF()
    private var score: Int = 58
    private var riskLevel: String = "moderate"
    private var ringStrokePx: Float = V2Ui.dp(context, 10).toFloat()

    private val orbView = ImageView(context).apply {
        setImageResource(R.drawable.hiair_orb)
        imageTintList = null
        scaleType = ImageView.ScaleType.FIT_CENTER
        alpha = 0.92f
    }
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
        setTextColor(HiAirColors.Spectrum.cyan)
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
            orbView,
            LayoutParams(V2Ui.dp(context, 160), V2Ui.dp(context, 160), Gravity.CENTER),
        )
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
        val widthDp = context.resources.configuration.screenWidthDp
        val targetDp = HiAirScreenMetrics.heroOrbDp(widthDp).coerceAtLeast(220)
        val min = V2Ui.dp(context, targetDp)
        val size = resolveSize(min, widthMeasureSpec).coerceAtMost(resolveSize(min, heightMeasureSpec))
        setMeasuredDimension(size, size)
        val orbSize = (size * 0.72f).toInt()
        orbView.layoutParams = LayoutParams(orbSize, orbSize, Gravity.CENTER)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val radius = minOf(width, height) / 2f
        val inset = ringStrokePx / 2f + V2Ui.dp(context, 4)
        arcBounds.set(inset, inset, width - inset, height - inset)

        glowPaint.shader = RadialGradient(
            cx,
            cy,
            radius,
            intArrayOf(
                (HiAirColors.Spectrum.cyan and 0x00FFFFFF) or 0x4D000000,
                Color.TRANSPARENT,
            ),
            floatArrayOf(0.2f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx, cy, radius, glowPaint)
        glowPaint.shader = null

        canvas.drawCircle(cx, cy, radius * 0.74f, diskPaint)
        canvas.drawCircle(cx, cy, radius * 0.74f, diskStrokePaint)

        ringPaint.strokeWidth = ringStrokePx
        val shader = SweepGradient(
            cx,
            cy,
            intArrayOf(
                HiAirColors.Spectrum.cyan,
                HiAirColors.Spectrum.electricBlue,
                HiAirColors.Spectrum.violet,
                HiAirColors.Spectrum.magenta,
                HiAirColors.Spectrum.cyan,
            ),
            null,
        )
        ringPaint.shader = shader
        canvas.drawArc(arcBounds, -90f, 360f, false, ringPaint)
        ringPaint.shader = null

        canvas.drawCircle(cx, cy, radius * 0.82f, innerRingPaint)
    }
}
