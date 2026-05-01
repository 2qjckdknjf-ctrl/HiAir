package com.hiair.ui.render

import android.graphics.Color
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.design.Tokens
import com.hiair.ui.theme.V2Ui

internal object SymptomsScreenRenderer {
    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val titleView = ctx.titleView
        val bodyContainer = ctx.bodyContainer

        var coughSelected = false
        var wheezeSelected = false
        var headacheSelected = false
        var fatigueSelected = false

        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("common.city_updated")).apply { textSize = 11f })
        titleView.text = ctx.l("title.symptoms")
        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("symptoms.subtitle")).apply { textSize = 13f })
        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("symptoms.streak")).apply {
            textSize = 12f
            setPadding(V2Ui.dp(activity, 10), V2Ui.dp(activity, 6), V2Ui.dp(activity, 10), V2Ui.dp(activity, 6))
            background = V2Ui.cardBackground(activity, "#1C355A", "#325888", 999)
        })
        val profileInput = EditText(activity).apply { hint = ctx.l("symptoms.profile_id") }
        val coughPill = symptomPill(activity, "💨 ${ctx.l("symptoms.cough")}") { selected ->
            coughSelected = selected
        }
        val wheezePill = symptomPill(activity, "🫁 ${ctx.l("symptoms.wheeze")}") { selected ->
            wheezeSelected = selected
        }
        val headachePill = symptomPill(activity, "🤕 ${ctx.l("symptoms.headache")}") { selected ->
            headacheSelected = selected
        }
        val fatiguePill = symptomPill(activity, "😮‍💨 ${ctx.l("symptoms.fatigue")}") { selected ->
            fatigueSelected = selected
        }
        val sleepInput = EditText(activity).apply { hint = ctx.l("symptoms.sleep_quality"); setText("3") }
        val intensityInput = EditText(activity).apply { hint = ctx.l("symptoms.quick_intensity"); setText("2") }
        val stateText = TextView(activity).apply {
            text = ctx.l("symptoms.fill_submit")
            textSize = 16f
            setTextColor(Color.parseColor("#A6B6D2"))
        }

        val submitButton = V2Ui.primaryButton(activity, ctx.l("symptoms.submit")).apply {
            setOnClickListener {
                stateText.text = ctx.l("symptoms.submitting")
                val sleep = sleepInput.text.toString().toIntOrNull()?.coerceIn(1, 5) ?: 3
                val intensity = intensityInput.text.toString().toIntOrNull()?.coerceIn(1, 5) ?: 2
                rootShell.symptomLogViewModel.updateProfileId(profileInput.text.toString())
                rootShell.symptomLogViewModel.setQuickIntensity(intensity)
                rootShell.symptomLogViewModel.updateToggles(
                    cough = coughSelected,
                    wheeze = wheezeSelected,
                    headache = headacheSelected,
                    fatigue = fatigueSelected,
                    sleepQuality = sleep
                )
                Thread {
                    val settings = rootShell.settingsViewModel.state
                    rootShell.symptomLogViewModel.submit(
                        userId = settings.userId,
                        accessToken = settings.accessToken.ifBlank { null }
                    )
                    val state = rootShell.symptomLogViewModel.state
                    activity.runOnUiThread { stateText.text = state.statusText }
                }.start()
            }
        }

        val quickBreathButton = V2Ui.secondaryButton(activity, ctx.l("symptoms.quick_breath")).apply {
            setOnClickListener { quickSymptom(ctx, profileInput, intensityInput, stateText, "breath_discomfort") }
        }
        val quickHeadacheButton = V2Ui.secondaryButton(activity, ctx.l("symptoms.quick_headache")).apply {
            setOnClickListener { quickSymptom(ctx, profileInput, intensityInput, stateText, "headache") }
        }

        val symptomCard = V2Ui.cardContainer(activity).apply {
            addView(profileInput)
            addView(LinearLayout(activity).apply {
                orientation = LinearLayout.HORIZONTAL
                addView(coughPill)
                addView(wheezePill)
            })
            addView(LinearLayout(activity).apply {
                orientation = LinearLayout.HORIZONTAL
                addView(headachePill)
                addView(fatiguePill)
            })
            addView(sleepInput)
            addView(intensityInput)
            addView(quickBreathButton)
            addView(quickHeadacheButton)
            addView(stateText)
        }
        bodyContainer.addView(symptomCard)
        bodyContainer.addView(submitButton)
    }

    private fun symptomPill(
        activity: android.app.Activity,
        label: String,
        onChange: (Boolean) -> Unit
    ): TextView {
        var selected = false
        return TextView(activity).apply {
            text = label
            textSize = 13f
            setTextColor(Tokens.Text.secondary)
            setPadding(V2Ui.dp(activity, 10), V2Ui.dp(activity, 8), V2Ui.dp(activity, 10), V2Ui.dp(activity, 8))
            background = V2Ui.cardBackground(activity, "#20385D", "#355987", 999)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginEnd = V2Ui.dp(activity, 6)
                topMargin = V2Ui.dp(activity, 6)
            }
            setOnClickListener {
                selected = !selected
                onChange(selected)
                setTextColor(if (selected) Tokens.Text.primary else Tokens.Text.secondary)
                background = V2Ui.cardBackground(
                    activity,
                    if (selected) "#2B5A8A" else "#20385D",
                    if (selected) "#67C6FF" else "#355987",
                    999
                )
            }
        }
    }

    private fun quickSymptom(
        ctx: RenderContext,
        profileInput: EditText,
        intensityInput: EditText,
        stateText: TextView,
        symptomType: String
    ) {
        val activity = ctx.activity
        val settings = ctx.rootShell.settingsViewModel.state
        val intensity = intensityInput.text.toString().toIntOrNull()?.coerceIn(1, 5) ?: 2
        ctx.rootShell.symptomLogViewModel.updateProfileId(profileInput.text.toString())
        ctx.rootShell.symptomLogViewModel.setQuickIntensity(intensity)
        Thread {
            ctx.rootShell.symptomLogViewModel.quickLog(
                userId = settings.userId,
                accessToken = settings.accessToken.ifBlank { null },
                symptomType = symptomType
            )
            val state = ctx.rootShell.symptomLogViewModel.state
            activity.runOnUiThread { stateText.text = state.statusText }
        }.start()
    }
}
