package com.hiair.ui.theme

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.design.TimeOfDayBackground
import com.hiair.ui.design.Tokens

object V2Ui {
    fun dp(context: Context, value: Int): Int = (value * context.resources.displayMetrics.density).toInt()

    fun spacer(context: Context, heightDp: Int): View = View(context).apply {
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(context, heightDp)
        )
    }

    fun cardBackground(context: Context, fillHex: String, strokeHex: String, radiusDp: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(context, radiusDp).toFloat()
            setColor(Color.parseColor(fillHex))
            setStroke(dp(context, 1), Color.parseColor(strokeHex))
        }
    }

    fun cardContainer(context: Context): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(context, 14), dp(context, 14), dp(context, 14), dp(context, 14))
            background = cardBackground(
                context,
                fillHex = colorHex(TimeOfDayBackground.surfacePrimary()),
                strokeHex = "#2E4B76",
                radiusDp = Tokens.RadiusDp.lg
            )
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            params.topMargin = dp(context, 12)
            layoutParams = params
        }
    }

    fun styledBodyText(context: Context, text: String): TextView {
        return TextView(context).apply {
            this.text = text
            textSize = 18f
            setTextColor(Tokens.Text.primary)
        }
    }

    fun styledSecondaryText(context: Context, text: String): TextView {
        return TextView(context).apply {
            this.text = text
            textSize = 14f
            setTextColor(Tokens.Text.secondary)
        }
    }

    fun navButton(context: Context, label: String, onTap: () -> Unit): Button {
        return Button(context).apply {
            text = label
            textSize = 11f
            setTextColor(Tokens.Cta.start)
            minHeight = dp(context, 38)
            background = cardBackground(context, "#1B3A62", strokeHex = "#325888", radiusDp = 13)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(context, 3)
                marginEnd = dp(context, 3)
            }
            setOnClickListener { onTap() }
        }
    }

    fun primaryButton(context: Context, label: String): Button {
        return Button(context).apply {
            text = label
            setTextColor(Color.parseColor("#0D172A"))
            textSize = 15f
            setTypeface(typeface, Typeface.BOLD)
            minHeight = dp(context, 48)
            background = GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                intArrayOf(Tokens.Cta.start, Tokens.Cta.end)
            ).apply {
                cornerRadius = dp(context, Tokens.RadiusDp.md).toFloat()
            }
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            params.topMargin = dp(context, 12)
            layoutParams = params
        }
    }

    fun secondaryButton(context: Context, label: String): Button {
        return Button(context).apply {
            text = label
            setTextColor(Tokens.Text.primary)
            minHeight = dp(context, 44)
            background = cardBackground(
                context,
                fillHex = colorHex(TimeOfDayBackground.surfaceSecondary()),
                strokeHex = "#355987",
                radiusDp = 13
            )
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            params.topMargin = dp(context, 6)
            layoutParams = params
        }
    }

    fun applyRiskGlobeStyle(context: Context, orb: View, riskLevel: String, glowStrength: Float) {
        val primary = Tokens.RiskAccent.forLevel(riskLevel)
        val secondary = Color.parseColor("#66C7FF")
        orb.background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            colors = intArrayOf(primary, secondary)
            gradientType = GradientDrawable.RADIAL_GRADIENT
            gradientRadius = dp(context, 48).toFloat()
            alpha = (120 + glowStrength * 100).toInt().coerceIn(120, 230)
        }
        orb.elevation = dp(context, 12).toFloat() * glowStrength
    }

    fun startRiskGlobeAnimation(context: Context, orb: View, currentRiskLevel: () -> String) {
        ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2800L
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
            addUpdateListener { animator ->
                val progress = animator.animatedFraction
                val scale = 0.96f + progress * 0.08f
                orb.scaleX = scale
                orb.scaleY = scale
                applyRiskGlobeStyle(context, orb, currentRiskLevel(), glowStrength = 0.6f + progress * 0.4f)
            }
            start()
        }
    }

    private fun colorHex(colorInt: Int): String = String.format("#%08X", colorInt)
}
