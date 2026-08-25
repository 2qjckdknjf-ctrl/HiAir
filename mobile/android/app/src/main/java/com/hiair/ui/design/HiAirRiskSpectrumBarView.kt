package com.hiair.ui.design

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.util.AttributeSet
import android.view.View
import com.hiair.ui.theme.V2Ui

/** V4 risk spectrum bar with score indicator (matches iOS HiAirRiskSpectrumBar). */
class HiAirRiskSpectrumBarView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    private var score: Int = 45
    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val thumbPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        setShadowLayer(V2Ui.dp(context, 6).toFloat(), 0f, 0f, HiAirColors.Spectrum.cyan)
    }
    private val trackBounds = RectF()

    init {
        setLayerType(LAYER_TYPE_SOFTWARE, null)
    }

    fun bind(score: Int) {
        this.score = score.coerceIn(0, 100)
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val height = V2Ui.dp(context, 24)
        setMeasuredDimension(resolveSize(V2Ui.dp(context, 200), widthMeasureSpec), height)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val barHeight = V2Ui.dp(context, 8).toFloat()
        val top = (height - barHeight) / 2f
        trackBounds.set(0f, top, width.toFloat(), top + barHeight)
        trackPaint.shader = LinearGradient(
            0f,
            top,
            width.toFloat(),
            top,
            intArrayOf(
                HiAirColors.Risk.low,
                HiAirColors.Spectrum.cyan,
                HiAirColors.Risk.moderate,
                HiAirColors.Risk.high,
                HiAirColors.Risk.veryHigh,
                HiAirColors.Spectrum.magenta,
            ),
            null,
            Shader.TileMode.CLAMP,
        )
        canvas.drawRoundRect(trackBounds, barHeight / 2f, barHeight / 2f, trackPaint)
        trackPaint.shader = null

        val progress = score / 100f
        val thumbRadius = V2Ui.dp(context, 8).toFloat()
        val cx = (width * progress).coerceIn(thumbRadius, width - thumbRadius)
        canvas.drawCircle(cx, height / 2f, thumbRadius, thumbPaint)
    }
}
