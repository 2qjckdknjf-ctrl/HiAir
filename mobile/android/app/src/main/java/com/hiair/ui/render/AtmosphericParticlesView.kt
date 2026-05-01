package com.hiair.ui.render

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.view.View
import com.hiair.ui.design.AtmosphericParticlesConfig
import com.hiair.ui.design.ParticleConfig
import kotlin.math.cos
import kotlin.math.sin

class AtmosphericParticlesView(context: Context) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private var time = 0f
    private var config: ParticleConfig = AtmosphericParticlesConfig.forPm25(25.0)
    private var tintColor: Int = 0xFFFFFFFF.toInt()

    private val ticker = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 1600L
        repeatCount = ValueAnimator.INFINITE
        addUpdateListener {
            time += config.speed * 0.85f
            invalidate()
        }
    }

    init {
        ticker.start()
    }

    fun setPm25(pm25: Double) {
        config = AtmosphericParticlesConfig.forPm25(pm25)
        invalidate()
    }

    fun setTintColor(color: Int) {
        tintColor = color
        invalidate()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        ticker.cancel()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (width <= 0 || height <= 0) {
            return
        }
        for (idx in 0 until config.count) {
            val x = ((sin((idx + 1) * 1.73 + time * 0.42) * 0.5) + 0.5) * width
            val y = ((cos((idx + 1) * 2.11 + time * 0.35) * 0.5) + 0.5) * height
            val radius = (1.5f + (idx % 3))
            val alpha = config.minOpacity + (idx.toFloat() / config.count.coerceAtLeast(1)) * (config.maxOpacity - config.minOpacity)
            paint.color = tintColor
            paint.alpha = (alpha * 255).toInt().coerceIn(0, 255)
            canvas.drawCircle(x.toFloat(), y.toFloat(), radius * resources.displayMetrics.density, paint)
        }
    }
}
