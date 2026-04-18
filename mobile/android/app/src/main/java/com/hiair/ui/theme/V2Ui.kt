package com.hiair.ui.theme

import android.animation.ArgbEvaluator
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

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
            background = cardBackground(context, "#132848", strokeHex = "#2E4B76", radiusDp = 18)
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
            setTextColor(Color.parseColor("#EAF1FB"))
        }
    }

    fun styledSecondaryText(context: Context, text: String): TextView {
        return TextView(context).apply {
            this.text = text
            textSize = 14f
            setTextColor(Color.parseColor("#A6B6D2"))
        }
    }

    fun navButton(context: Context, label: String, onTap: () -> Unit): Button {
        return Button(context).apply {
            text = label
            textSize = 11f
            setTextColor(Color.parseColor("#64D7FF"))
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
                intArrayOf(Color.parseColor("#59D8FF"), Color.parseColor("#9A8CFF"))
            ).apply {
                cornerRadius = dp(context, 16).toFloat()
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
            setTextColor(Color.parseColor("#DCE8FA"))
            minHeight = dp(context, 44)
            background = cardBackground(context, "#20385D", strokeHex = "#355987", radiusDp = 13)
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            params.topMargin = dp(context, 6)
            layoutParams = params
        }
    }

    fun startWeatherAnimation(context: Context, orb: View, title: TextView, mood: TextView) {
        val states = listOf(
            Triple("Sunny 26C", "Mood: Calm", intArrayOf(Color.parseColor("#52E0B0"), Color.parseColor("#64B8FF"))),
            Triple("Heatwave 33C", "Mood: Stressed", intArrayOf(Color.parseColor("#FFA05C"), Color.parseColor("#FF6A73"))),
            Triple("Windy 22C", "Mood: Energized", intArrayOf(Color.parseColor("#6FC5FF"), Color.parseColor("#9C91FF")))
        )
        var index = 0
        ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2200L
            repeatCount = ValueAnimator.INFINITE
            addUpdateListener { animator ->
                val progress = animator.animatedFraction
                if (progress > 0.98f) {
                    index = (index + 1) % states.size
                    val state = states[index]
                    title.text = state.first
                    mood.text = state.second
                    orb.background = GradientDrawable().apply {
                        shape = GradientDrawable.OVAL
                        colors = state.third
                        gradientType = GradientDrawable.RADIAL_GRADIENT
                        gradientRadius = dp(context, 48).toFloat()
                    }
                }
                orb.scaleX = 0.96f + (progress * 0.08f)
                orb.scaleY = 0.96f + (progress * 0.08f)
                val alpha = ArgbEvaluator().evaluate(
                    progress,
                    Color.parseColor("#66FFFFFF"),
                    Color.parseColor("#99FFFFFF")
                ) as Int
                orb.background?.alpha = Color.alpha(alpha)
            }
            start()
        }
    }
}
