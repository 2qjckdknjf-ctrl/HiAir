package com.hiair.ui.render

import android.graphics.Color
import android.widget.CheckBox
import android.widget.EditText
import android.widget.TextView
import com.hiair.ui.theme.V2Ui

internal object SymptomsScreenRenderer {
    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val titleView = ctx.titleView
        val bodyContainer = ctx.bodyContainer

        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("common.city_updated")).apply { textSize = 11f })
        titleView.text = ctx.l("title.symptoms")
        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("symptoms.subtitle")).apply { textSize = 13f })
        val profileInput = EditText(activity).apply { hint = ctx.l("symptoms.profile_id") }
        val coughBox = CheckBox(activity).apply { text = ctx.l("symptoms.cough") }
        val wheezeBox = CheckBox(activity).apply { text = ctx.l("symptoms.wheeze") }
        val headacheBox = CheckBox(activity).apply { text = ctx.l("symptoms.headache") }
        val fatigueBox = CheckBox(activity).apply { text = ctx.l("symptoms.fatigue") }
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
                    cough = coughBox.isChecked,
                    wheeze = wheezeBox.isChecked,
                    headache = headacheBox.isChecked,
                    fatigue = fatigueBox.isChecked,
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
            addView(coughBox)
            addView(wheezeBox)
            addView(headacheBox)
            addView(fatigueBox)
            addView(sleepInput)
            addView(intensityInput)
            addView(quickBreathButton)
            addView(quickHeadacheButton)
            addView(stateText)
        }
        bodyContainer.addView(symptomCard)
        bodyContainer.addView(submitButton)
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
